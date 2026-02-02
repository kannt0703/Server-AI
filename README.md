Đối với server AI tầm trung (từ vài chục nghìn đến vài trăm nghìn văn bản, cần truy vấn nhanh và ổn định), tôi khuyên dùng kết hợp 2 phương pháp sau để đạt hiệu quả tối ưu về hiệu năng, tính linh hoạt và độ phức tạp khi bảo trì:

🏗️ Kiến Trúc Đề Xuất: Kết Hợp “Làm Phẳng” + Cơ Sở Dữ Liệu Bên Ngoài

Nguyên tắc chính: Lưu trữ thông tin dùng để lọc trực tiếp trong metadata của ChromaDB, và lưu toàn bộ thông tin chi tiết, phức tạp vào một cơ sở dữ liệu quan hệ (như PostgreSQL, MySQL) hoặc NoSQL (MongoDB).

Sơ đồ luồng dữ liệu:

```
[Dữ liệu thô] --> [Xử lý & Trích xuất]
                            |
                            v
      [Metadata quan trọng] + [Embedding] --> Lưu vào **ChromaDB** (cho tìm kiếm vector & lọc nhanh)
                            |
                            v
      [Toàn bộ dữ liệu chi tiết] ----------> Lưu vào **SQL/NoSQL DB** (cho truy vấn phức tạp & hiển thị)
```

---

💻 Triển Khai Mẫu

Bước 1: Thiết Kế Schema & Lưu Dữ Liệu

```python
import chromadb
import json
from datetime import datetime

# Khởi tạo ChromaDB Persistent Client để dữ liệu tồn tại giữa các lần chạy server
client = chromadb.PersistentClient(path="./chroma_storage")
collection = client.get_or_create_collection(
    name="document_embeddings",
    metadata={"hnsw:space": "cosine"} # Tối ưu cho tìm kiếm tương đồng
)

# Giả sử bạn có một tài liệu với đầy đủ thông tin
full_document_data = {
    "internal_id": 78901, # ID chính trong SQL DB
    "title": "Báo cáo thị trường AI 2024",
    "content": "Nội dung dài và chi tiết của báo cáo...",
    "author": {"id": 101, "name": "Nguyễn Văn A", "department": "R&D"},
    "tags": ["thị trường", "AI", "dự báo", "Việt Nam"],
    "categories": ["kinh tế", "công nghệ"],
    "published_date": "2024-05-27T00:00:00Z",
    "file_attributes": {
        "type": "pdf",
        "size_kb": 2048,
        "pages": 20,
        "download_url": "/files/report_2024.pdf"
    },
    "permissions": ["view", "edit"],
    "version": "2.1",
    "status": "published"
}

# --- CHUẨN BỊ METADATA CHO CHROMADB (Tối ưu cho lọc) ---
chroma_metadata = {
    # 1. Các trường lọc cơ bản & hiệu suất cao (SỐ, CHUỖI NGẮN)
    "doc_id": str(full_document_data["internal_id"]), # Liên kết ngược về SQL DB
    "title": full_document_data["title"],
    "year": 2024, # Trích xuất từ published_date
    "month": 5,
    
    # 2. Các trường dùng để lọc phân loại
    "main_category": full_document_data["categories"][0] if full_document_data["categories"] else None,
    "status": full_document_data["status"],
    
    # 3. Xử lý danh sách tags -> Lưu dưới dạng chuỗi phân cách cho lọc đơn giản ($contains)
    "tags_str": ",".join(full_document_data["tags"]),
    "has_ai_tag": "AI" in full_document_data["tags"], # Trường boolean tối ưu riêng
    
    # 4. Thông tin tác giả (làm phẳng)
    "author_id": full_document_data["author"]["id"],
    "author_name": full_document_data["author"]["name"],
    
    # 5. Lưu một vài trường phức tạp dưới dạng JSON (CHỈ dành cho hiển thị, không dùng để lọc)
    "file_attrs_json": json.dumps(full_document_data["file_attributes"], ensure_ascii=False)
}

# --- LƯU VÀO CHROMADB ---
collection.upsert(
    ids=[f"doc_{full_document_data['internal_id']}"],
    documents=[full_document_data["content"]], # Chỉ lưu nội dung chính để embedding
    metadatas=[chroma_metadata]
)

# --- LƯU TOÀN BỘ DỮ LIỆU VÀO SQL DB (Ví dụ dùng SQLAlchemy) ---
# Giả sử bạn đã có model `Document` và kết nối database
# new_doc = Document(
#     id=full_document_data["internal_id"],
#     title=full_document_data["title"],
#     full_data=json.dumps(full_document_data), # Hoặc lưu từng cột riêng biệt
#     created_at=datetime.now()
# )
# db_session.add(new_doc)
# db_session.commit()
```

Bước 2: Truy Vấn & Kết Hợp Dữ Liệu

```python
def search_documents(query_text, filters=None):
    """
    Hàm tìm kiếm chính trên server: kết hợp tìm kiếm ngữ nghĩa và lọc metadata.
    """
    # Bước 1: Truy vấn ChromaDB với các bộ lọc cơ bản
    where_clause = {"status": {"$eq": "published"}} # Lọc mặc định
    if filters:
        if "year" in filters:
            where_clause["year"] = {"$eq": filters["year"]}
        if "category" in filters:
            where_clause["main_category"] = {"$eq": filters["category"]}
        if "author_id" in filters:
            where_clause["author_id"] = {"$eq": filters["author_id"]}
    
    chroma_results = collection.query(
        query_texts=[query_text],
        n_results=10,
        where=where_clause,
        include=["metadatas", "distances", "documents"]
    )
    
    # Bước 2: Lấy ID đầy đủ và tìm nạp thông tin chi tiết từ SQL DB
    detailed_results = []
    if chroma_results['ids'][0]:
        doc_ids_from_chroma = [int(meta['doc_id']) for meta in chroma_results['metadatas'][0]]
        
        # GIẢ ĐỊNH: Hàm truy vấn SQL để lấy thông tin đầy đủ
        # full_docs_from_sql = db_session.query(Document).filter(Document.id.in_(doc_ids_from_chroma)).all()
        # full_docs_dict = {doc.id: doc for doc in full_docs_from_sql}
        
        # Bước 3: Kết hợp kết quả
        for idx, chroma_id in enumerate(chroma_results['ids'][0]):
            combined_data = {
                "chroma_id": chroma_id,
                "score": chroma_results['distances'][0][idx],
                "excerpt": chroma_results['documents'][0][idx][:200], # Trích đoạn ngắn
                "metadata": chroma_results['metadatas'][0][idx],
                # "full_document": full_docs_dict[int(chroma_results['metadatas'][0][idx]['doc_id'])].full_data
            }
            detailed_results.append(combined_data)
    
    return detailed_results

# Ví dụ sử dụng trên server API endpoint
# Kết quả trả về bao gồm: thông tin tìm kiếm vector từ Chroma + metadata chi tiết từ SQL
```

---

🎯 Ưu Điểm Của Kiến Trúc Này Cho Server Tầm Trung

1. Hiệu năng cao: ChromaDB chỉ phải xử lý các trường lọc đơn giản, tăng tốc độ truy vấn.
2. Linh hoạt tuyệt đối: Bạn có thể thay đổi schema dữ liệu chi tiết trong SQL mà không cần rebuild toàn bộ vector database.
3. Truy vấn phức tạp: Thực hiện các join, aggregate, full-text search phức tạp trên SQL (việc ChromaDB không làm được).
4. Quản lý dữ liệu chắc chắn: SQL DB cung cấp transaction, backup, user permissions - điều ChromaDB không có.
5. Dễ mở rộng: Khi dữ liệu tăng, bạn có thể scale ChromaDB và SQL DB độc lập.

⚙️ Cấu Hình & Lưu Ý Triển Khai

```yaml
# docker-compose.yml cho triển khai server tầm trung
version: '3.8'
services:
  chromadb:
    image: chromadb/chroma:latest
    volumes:
      - ./chroma_data:/chroma/chroma
    environment:
      - IS_PERSISTENT=TRUE
      - PERSIST_DIRECTORY=/chroma/chroma
    ports:
      - "8000:8000"
  
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: strongpassword
    volumes:
      - ./postgres_data:/var/lib/postgresql/data
  
  your_ai_server:
    build: .
    depends_on:
      - chromadb
      - postgres
    environment:
      CHROMA_HOST: chromadb
      DATABASE_URL: postgresql://admin:strongpassword@postgres/myapp
```

Lưu ý quan trọng:

· Đánh chỉ mục metadata trong ChromaDB: Khi tạo collection, hãy chỉ định các trường sẽ lọc thường xuyên để tối ưu tốc độ.
· Thiết kế ID thông minh: Dùng ID có cấu trúc (như doc_<sql_id>_v<version>) để dễ quản lý.
· Đồng bộ hóa dữ liệu: Cần cơ chế đảm bảo khi xóa/update dữ liệu trong SQL thì ChromaDB cũng được cập nhật (dùng message queue như Redis hoặc hooks trong ứng dụng).

Kiến trúc này cung cấp nền tảng vững chắc, hiệu suất cao và dễ bảo trì cho server AI tầm trung, cho phép bạn tập trung vào phát triển logic nghiệp vụ thay vì loay hoay với hạn chế của vector database.


🏗️ Kiến Trúc Tích Hợp ChromaDB Vào Server AI Hiện Tại

📁 Cấu Trúc Thư Mục Được Cải Tổ

```
ai-server/
├── gateway/
│   ├── main.py                    # FastAPI/Flask server chính
│   ├── database_utils.py          # Mở rộng: kết nối ChromaDB + SQL
│   ├── ai_utils.py                # Mở rộng: embedding, xử lý RAG
│   ├── chroma_manager.py          # NEW: Quản lý ChromaDB operations
│   ├── sql_models.py              # NEW: SQLAlchemy models
│   └── requirements.txt           # Cập nhật dependencies
├── webchat/
│   ├── index.html
│   ├── style.css
│   └── script.js                  # Thêm gọi API ChromaDB
├── docker-compose.yml             # Thêm services ChromaDB & PostgreSQL
├── .env.example                   # Biến môi trường
└── data/
    ├── chroma_storage/            # Persistent data ChromaDB
    └── uploads/                   # File uploads
```

---

🔧 Các File Chính Được Triển Khai

1. docker-compose.yml - Triển Khai Multi-Service

```yaml
version: '3.8'
services:
  # ChromaDB Service
  chromadb:
    image: chromadb/chroma:latest
    container_name: ai_chromadb
    environment:
      - IS_PERSISTENT=TRUE
      - PERSIST_DIRECTORY=/chroma/chroma_data
      - ANONYMIZED_TELEMETRY=FALSE
    volumes:
      - ./data/chroma_storage:/chroma/chroma_data
    ports:
      - "8000:8000"
    restart: unless-stopped
    networks:
      - ai_network

  # PostgreSQL cho metadata chi tiết
  postgres:
    image: postgres:15-alpine
    container_name: ai_postgres
    environment:
      POSTGRES_DB: ai_metadata
      POSTGRES_USER: ai_user
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - ./data/postgres:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    ports:
      - "5432:5432"
    networks:
      - ai_network

  # Gateway Server (chính)
  gateway:
    build: ./gateway
    container_name: ai_gateway
    volumes:
      - ./gateway:/app
      - ./data/uploads:/app/uploads
    ports:
      - "5000:5000"
    environment:
      - CHROMA_HOST=chromadb
      - CHROMA_PORT=8000
      - DATABASE_URL=postgresql://ai_user:${DB_PASSWORD}@postgres/ai_metadata
      - EMBEDDING_MODEL=keepitreal/vietnamese-sbert
    depends_on:
      - chromadb
      - postgres
    networks:
      - ai_network
    restart: always

networks:
  ai_network:
    driver: bridge
```

2. gateway/chroma_manager.py - Quản Lý ChromaDB Chuyên Sâu

```python
import chromadb
from chromadb.config import Settings
from typing import List, Dict, Any, Optional
import json
from datetime import datetime
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ChromaManager:
    def __init__(self, host="chromadb", port=8000):
        """Khởi tạo kết nối đến ChromaDB server"""
        self.client = chromadb.HttpClient(
            host=host,
            port=port,
            settings=Settings(allow_reset=True, anonymized_telemetry=False)
        )
        self.collection = None
        
    def get_or_create_collection(self, name: str, embedding_model: str = None):
        """Lấy hoặc tạo collection với cấu hình tối ưu"""
        try:
            self.collection = self.client.get_or_create_collection(
                name=name,
                metadata={
                    "hnsw:space": "cosine",
                    "hnsw:construction_ef": 200,
                    "hnsw:M": 16,
                    "description": f"Collection for AI server - {datetime.now().strftime('%Y-%m-%d')}"
                }
            )
            logger.info(f"Collection '{name}' ready")
            return self.collection
        except Exception as e:
            logger.error(f"Failed to create collection: {e}")
            raise
    
    def add_document(self, document_id: str, content: str, metadata: Dict, embedding: List[float] = None):
        """Thêm document với metadata được tối ưu cho truy vấn"""
        # Chuẩn hóa metadata: làm phẳng cấu trúc phức tạp
        processed_metadata = self._process_metadata(metadata)
        
        # Thêm timestamp cho quản lý
        processed_metadata["chroma_created_at"] = datetime.now().isoformat()
        
        # Lưu vào ChromaDB
        if embedding:
            self.collection.add(
                ids=[document_id],
                embeddings=[embedding],
                metadatas=[processed_metadata],
                documents=[content]
            )
        else:
            self.collection.add(
                ids=[document_id],
                documents=[content],
                metadatas=[processed_metadata]
            )
        
        logger.info(f"Document {document_id} added to ChromaDB")
        return document_id
    
    def _process_metadata(self, metadata: Dict) -> Dict:
        """Chuẩn hóa metadata: làm phẳng cấu trúc phức tạp và chuyển đổi kiểu"""
        processed = {}
        
        for key, value in metadata.items():
            if isinstance(value, (list, tuple)):
                # Xử lý list: lưu dưới dạng JSON string + tạo trường boolean cho item quan trọng
                processed[f"{key}_json"] = json.dumps(value, ensure_ascii=False)
                if key == "tags" and value:
                    # Tạo trường boolean cho tags phổ biến
                    for tag in ["urgent", "important", "review"]:
                        processed[f"tag_{tag}"] = tag in value
            elif isinstance(value, dict):
                # Xử lý dict: làm phẳng các trường quan trọng
                processed[f"{key}_json"] = json.dumps(value, ensure_ascii=False)
                # Trích xuất các trường thường dùng để lọc
                if "status" in value:
                    processed[f"{key}_status"] = value["status"]
                if "priority" in value:
                    processed[f"{key}_priority"] = value["priority"]
            elif isinstance(value, datetime):
                processed[key] = value.isoformat()
            elif isinstance(value, (int, float, str, bool, type(None))):
                # ChromaDB hỗ trợ trực tiếp các kiểu này
                processed[key] = value
            else:
                # Chuyển đổi thành string cho các kiểu khác
                processed[key] = str(value)
        
        return processed
    
    def semantic_search(self, query: str, filters: Dict = None, n_results: int = 5):
        """Tìm kiếm ngữ nghĩa với bộ lọc metadata"""
        where_clause = self._build_where_clause(filters) if filters else {}
        
        results = self.collection.query(
            query_texts=[query],
            n_results=n_results,
            where=where_clause,
            include=["metadatas", "documents", "distances"]
        )
        
        # Xử lý kết quả: parse lại JSON fields
        parsed_results = []
        for i in range(len(results["ids"][0])):
            item = {
                "id": results["ids"][0][i],
                "content": results["documents"][0][i],
                "score": float(results["distances"][0][i]),
                "metadata": self._parse_metadata(results["metadatas"][0][i])
            }
            parsed_results.append(item)
        
        return parsed_results
    
    def _build_where_clause(self, filters: Dict) -> Dict:
        """Xây dựng where clause cho ChromaDB từ filters dict"""
        where = {}
        
        for key, value in filters.items():
            if isinstance(value, list):
                where[key] = {"$in": value}
            elif isinstance(value, dict) and "range" in value:
                # Hỗ trợ range query
                range_op = {}
                if "min" in value:
                    range_op["$gte"] = value["min"]
                if "max" in value:
                    range_op["$lte"] = value["max"]
                where[key] = range_op
            else:
                where[key] = {"$eq": value}
        
        return where
    
    def _parse_metadata(self, metadata: Dict) -> Dict:
        """Parse lại các trường JSON trong metadata"""
        parsed = metadata.copy()
        
        for key, value in metadata.items():
            if key.endswith("_json") and isinstance(value, str):
                try:
                    parsed[key.replace("_json", "")] = json.loads(value)
                    del parsed[key]  # Xóa trường json gốc
                except:
                    pass
        
        return parsed

# Singleton instance
chroma_manager = ChromaManager()
```

3. gateway/database_utils.py - Quản Lý Kết Nối Đa Database

```python
import psycopg2
from psycopg2.extras import RealDictCursor
import json
from .chroma_manager import chroma_manager
from functools import lru_cache
import os

class DatabaseManager:
    def __init__(self):
        self.pg_conn = None
        self.chroma = chroma_manager
        
    def init_databases(self):
        """Khởi tạo kết nối đến cả PostgreSQL và ChromaDB"""
        # Kết nối PostgreSQL
        self.pg_conn = psycopg2.connect(
            os.getenv("DATABASE_URL"),
            cursor_factory=RealDictCursor
        )
        
        # Khởi tạo ChromaDB collection
        self.chroma.get_or_create_collection("ai_documents")
        
        print("✅ Databases initialized: PostgreSQL + ChromaDB")
    
    def store_document(self, document_data: Dict):
        """Lưu document vào cả PostgreSQL (chi tiết) và ChromaDB (vector search)"""
        # 1. Lưu chi tiết vào PostgreSQL
        with self.pg_conn.cursor() as cursor:
            cursor.execute("""
                INSERT INTO documents 
                (id, title, content, full_metadata, created_at)
                VALUES (%s, %s, %s, %s, NOW())
                RETURNING id
            """, (
                document_data["id"],
                document_data.get("title", ""),
                document_data.get("content", ""),
                json.dumps(document_data.get("metadata", {}))
            ))
            doc_id = cursor.fetchone()["id"]
            self.pg_conn.commit()
        
        # 2. Lưu vào ChromaDB cho semantic search
        # Chỉ lưu metadata đã được làm phẳng và nội dung chính
        chroma_manager.add_document(
            document_id=doc_id,
            content=document_data.get("content", ""),
            metadata=document_data.get("metadata", {})
        )
        
        return {
            "sql_id": doc_id,
            "chroma_id": doc_id,
            "message": "Document stored in both databases"
        }
    
    def hybrid_search(self, query: str, filters: Dict = None):
        """
        Tìm kiếm lai: semantic search từ ChromaDB + exact match từ PostgreSQL
        """
        # 1. Semantic search từ ChromaDB
        semantic_results = chroma_manager.semantic_search(query, filters)
        
        # 2. Nếu có filters phức tạp, query thêm từ PostgreSQL
        pg_results = []
        if filters and any(k in filters for k in ["category", "status", "date_range"]):
            pg_results = self._postgres_search(filters)
        
        # 3. Kết hợp và xếp hạng kết quả
        combined = self._rank_results(semantic_results, pg_results)
        
        return combined
    
    def _postgres_search(self, filters: Dict):
        """Tìm kiếm exact match trong PostgreSQL"""
        query_parts = ["SELECT * FROM documents WHERE 1=1"]
        params = []
        
        if "category" in filters:
            query_parts.append("AND full_metadata->>'category' = %s")
            params.append(filters["category"])
        
        if "date_range" in filters:
            query_parts.append("AND created_at BETWEEN %s AND %s")
            params.extend([filters["date_range"]["start"], filters["date_range"]["end"]])
        
        with self.pg_conn.cursor() as cursor:
            cursor.execute(" ".join(query_parts), params)
            return cursor.fetchall()
    
    def _rank_results(self, semantic_results, pg_results):
        """Kết hợp và xếp hạng kết quả từ 2 nguồn"""
        # Simple scoring: ưu tiên semantic results, thêm exact matches
        scored = {}
        
        for result in semantic_results:
            scored[result["id"]] = {
                **result,
                "score": result.get("score", 0) * 0.7  # Trọng số cho semantic
            }
        
        for result in pg_results:
            if result["id"] in scored:
                # Tăng điểm nếu có trong cả 2 kết quả
                scored[result["id"]]["score"] += 0.3
            else:
                scored[result["id"]] = {
                    "id": result["id"],
                    "content": result["content"],
                    "metadata": json.loads(result["full_metadata"]),
                    "score": 0.3  # Điểm cơ bản cho exact match
                }
        
        return sorted(scored.values(), key=lambda x: x["score"], reverse=True)

# Global instance
db_manager = DatabaseManager()
```

4. gateway/main.py - API Gateway Mở Rộng

```python
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
from .database_utils import db_manager
from .ai_utils import create_embedding, process_rag_query
import uuid

app = FastAPI(title="AI Server Gateway")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://webchat:8080"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Models
class DocumentUpload(BaseModel):
    title: str
    content: str
    metadata: dict = {}
    category: Optional[str] = None

class SearchRequest(BaseModel):
    query: str
    filters: dict = {}
    top_k: int = 5

# Startup event
@app.on_event("startup")
async def startup():
    db_manager.init_databases()

# API Endpoints
@app.post("/api/documents/upload")
async def upload_document(doc: DocumentUpload):
    """Upload document với metadata phức tạp"""
    try:
        # Tạo ID duy nhất
        doc_id = f"doc_{uuid.uuid4().hex[:12]}"
        
        # Chuẩn bị dữ liệu
        document_data = {
            "id": doc_id,
            "title": doc.title,
            "content": doc.content,
            "metadata": {
                **doc.metadata,
                "category": doc.category,
                "source": "api_upload"
            }
        }
        
        # Lưu vào databases
        result = db_manager.store_document(document_data)
        
        return {
            "success": True,
            "document_id": result["sql_id"],
            "message": "Document stored successfully"
        }
    except Exception as e:
        raise HTTPException(500, f"Upload failed: {str(e)}")

@app.post("/api/documents/search")
async def search_documents(req: SearchRequest):
    """Tìm kiếm hybrid: semantic + exact match"""
    try:
        results = db_manager.hybrid_search(
            query=req.query,
            filters=req.filters
        )
        
        return {
            "query": req.query,
            "count": len(results),
            "results": results[:req.top_k]
        }
    except Exception as e:
        raise HTTPException(500, f"Search failed: {str(e)}")

@app.get("/api/documents/{doc_id}/similar")
async def find_similar(doc_id: str, top_k: int = 3):
    """Tìm document tương tự dựa trên embedding"""
    # Implement similar document search
    pass

# Health checks
@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "chromadb": "connected",
        "postgres": "connected"
    }
```

5. gateway/requirements.txt - Dependencies

```txt
# Core
fastapi==0.104.1
uvicorn[standard]==0.24.0
python-multipart==0.0.6

# Databases
chromadb==0.4.18
psycopg2-binary==2.9.9
sqlalchemy==2.0.23

# AI/ML
sentence-transformers==2.2.2
numpy==1.24.3
pydantic==2.5.0

# Utilities
python-dotenv==1.0.0
redis==5.0.1
celery==5.3.4  # Cho background tasks
```

---

🚀 Triển Khai & Chạy Hệ Thống

Bước 1: Khởi tạo PostgreSQL schema (init.sql)

```sql
CREATE TABLE IF NOT EXISTS documents (
    id VARCHAR(50) PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    full_metadata JSONB,
    embedding_vector BYTEA,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_documents_metadata ON documents USING gin(full_metadata);
CREATE INDEX idx_documents_created ON documents(created_at);
```

Bước 2: Cập nhật webchat/script.js để gọi API

```javascript
// Thêm hàm search đến gateway
async function searchDocuments(query) {
    const response = await fetch('http://localhost:5000/api/documents/search', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            query: query,
            filters: {
                category: 'technical',
                date_range: { min: '2024-01-01' }
            },
            top_k: 5
        })
    });
    
    return await response.json();
}

// Sử dụng trong chat interface
document.getElementById('search-btn').addEventListener('click', async () => {
    const query = document.getElementById('query-input').value;
    const results = await searchDocuments(query);
    
    // Hiển thị kết quả
    displayResults(results);
});
```

---

📊 Ưu Điểm Kiến Trúc Này Cho Server Tầm Trung

1. Hiệu năng tối ưu: ChromaDB xử lý vector search, PostgreSQL xử lý query phức tạp
2. Metadata linh hoạt: Hỗ trợ cấu trúc phức tạp nhưng vẫn query được
3. Dễ mở rộng: Thêm service mới (Redis cache, ElasticSearch) dễ dàng
4. Backup & Recovery: PostgreSQL có cơ chế backup mạnh, ChromaDB persistent storage
5. Monitoring: Có thể thêm Prometheus/Grafana để giám sát cả 2 DB

🔄 Workflow Hoạt Động

```
Người dùng upload -> Gateway nhận -> Xử lý AI (embedding) -> Lưu PostgreSQL (full) + ChromaDB (vector)
Người dùng search -> Query cả 2 DB -> Kết hợp kết quả -> Trả về
```

Bạn cần tôi triển khai thêm phần nào không? Ví dụ như:

1. Authentication cho API
2. Background tasks xử lý file upload lớn
3. Cache layer với Redis
4. Monitoring và logging
Để tích hợp tính năng "tìm kiếm Google" (thực chất là sử dụng mô hình AI của Google như Gemini) và tối ưu phân luồng dữ liệu cho phần cứng của bạn (i5-4570, 16GB RAM, không GPU), bạn có thể triển khai kiến trúc kết hợp như sau.

🔧 Tích Hợp Google Gemini Vào Hệ Thống

Tích hợp này sẽ biến hệ thống của bạn thành một RAG (Retrieval-Augmented Generation) server có khả năng tìm kiếm thông minh và trả lời câu hỏi dựa trên tài liệu nội bộ, sử dụng sức mạnh của Google AI từ xa để bù đắp cho việc thiếu GPU cục bộ.

1. Nguyên lý hoạt động

· Bước 1 (Truy xuất): Khi có câu hỏi, hệ thống dùng ChromaDB để tìm kiếm ngữ nghĩa và trả về các đoạn văn bản liên quan nhất từ kho dữ liệu riêng.
· Bước 2 (Tạo lập): Các đoạn văn bản này cùng với câu hỏi được đóng gói thành một "prompt" và gửi đến API Google Gemini. Gemini sẽ tổng hợp thông tin và tạo ra câu trả lời chính xác, tự nhiên.

2. Các bước tích hợp vào Gateway

Bạn cần sửa đổi/bổ sung các file trong thư mục gateway:

· Cập nhật gateway/requirements.txt: Thêm các thư viện cần thiết.
  ```txt
  google-generativeai>=0.3.0
  ```
· Tạo file gateway/gemini_client.py: Quản lý kết nối và gọi API Gemini.
  ```python
  import google.generativeai as genai
  import os
  from typing import List
  
  class GeminiClient:
      def __init__(self):
          api_key = os.getenv("GEMINI_API_KEY")  # Lấy key từ biến môi trường
          if not api_key:
              raise ValueError("Vui lòng đặt biến môi trường 'GEMINI_API_KEY'")
          genai.configure(api_key=api_key)
          self.model = genai.GenerativeModel('gemini-pro')  # Model dùng cho text
  
      def generate_answer(self, context: str, user_query: str) -> str:
          """Tạo câu trả lời từ ngữ cảnh và câu hỏi."""
          prompt = f"""
          Dựa trên tài liệu tham khảo sau đây, hãy trả lời câu hỏi của người dùng.
          Nếu thông tin trong tài liệu không đủ để trả lời, hãy nói 'Tôi không tìm thấy thông tin phù hợp trong tài liệu được cung cấp.'
  
          TÀI LIỆU THAM KHẢO:
          {context}
  
          CÂU HỎI: {user_query}
  
          CÂU TRẢ LỜI:
          """
          try:
              response = self.model.generate_content(prompt)
              return response.text
          except Exception as e:
              return f"Lỗi khi gọi Gemini API: {str(e)}"
  ```
· Cập nhật gateway/ai_utils.py: Tích hợp Gemini vào luồng xử lý RAG.
  ```python
  from .chroma_manager import chroma_manager
  from .gemini_client import GeminiClient
  
  class RAGProcessor:
      def __init__(self):
          self.gemini = GeminiClient()
  
      def process_query(self, query: str, filters: dict = None):
          """Xử lý truy vấn RAG hoàn chỉnh."""
          # 1. Tìm kiếm ngữ nghĩa trong ChromaDB
          search_results = chroma_manager.semantic_search(query, filters, n_results=3)
  
          if not search_results:
              return {"answer": "Không tìm thấy tài liệu phù hợp."}
  
          # 2. Kết hợp các đoạn văn bản liên quan nhất thành ngữ cảnh
          context = "\n---\n".join([item['content'] for item in search_results])
  
          # 3. Gọi Gemini để tạo câu trả lời từ ngữ cảnh
          answer = self.gemini.generate_answer(context, query)
  
          # 4. Trả về kết quả (có thể bao gồm cả các nguồn tham khảo)
          return {
              "answer": answer,
              "source_documents": search_results  # Để hiển thị nguồn gốc thông tin
          }
  ```
· Thêm endpoint API trong gateway/main.py:
  ```python
  from .ai_utils import RAGProcessor
  rag_processor = RAGProcessor()
  
  @app.post("/api/ask")
  async def ask_question(request_data: dict):
      """
      Endpoint hỏi-đáp thông minh sử dụng RAG và Google Gemini.
      Body: {"query": "Câu hỏi của bạn", "filters": {"category": "..."}}
      """
      query = request_data.get("query")
      if not query:
          raise HTTPException(status_code=400, detail="Thiếu 'query'")
  
      filters = request_data.get("filters", {})
      result = rag_processor.process_query(query, filters)
      return result
  ```

⚙️ Tối Ưu Phân Luồng & Hiệu Năng Cho CPU i5-4570

Với phần cứng đã cho, chiến lược tối ưu tập trung vào việc giảm tải CPU và tận dụng tối đa RAM.

1. Đánh giá phần cứng

· CPU Intel Core i5-4570: 4 nhân 4 luồng, xung nhịp 3.2 - 3.6 GHz. Đây là CPU thế hệ cũ, không hỗ trợ ép xung đáng kể, do đó tối ưu phần mềm là chìa khóa.
· RAM 16GB: Đủ cho server AI tầm trung, cần tránh rò rỉ bộ nhớ.
· SSD 128GB: Tốc độ đọc/ghi cao sẽ giúp việc truy xuất ChromaDB nhanh hơn nhiều so với HDD.
· Không có GPU: Mọi tính toán embedding và AI đều phải chạy trên CPU hoặc dùng dịch vụ từ xa (như Gemini API).

2. Các biện pháp tối ưu chính

Ưu tiên 1: Giảm tải Embedding cho CPU

· Sử dụng Embedding từ xa: Dùng GoogleGenerativeAiEmbeddingFunction của ChromaDB. Việc tính toán embedding tốn kém sẽ do server của Google xử lý, giải phóng hoàn toàn CPU của bạn.
· Cài đặt: Trong gateway/chroma_manager.py, khi tạo collection:
  ```python
  import chromadb.utils.embedding_functions as embedding_functions
  google_ef = embedding_functions.GoogleGenerativeAiEmbeddingFunction(api_key="YOUR_GOOGLE_AI_API_KEY")
  collection = client.get_or_create_collection(name="my_collection", embedding_function=google_ef)
  ```

Ưu tiên 2: Quản lý tài nguyên và phân luồng (trong docker-compose.yml)

```yaml
services:
  gateway:
    # ... các cấu hình khác
    deploy:
      resources:
        limits:
          cpus: '3.5' # Dành ~90% CPU vật lý (4 core) cho gateway
          memory: 12G # Giới hạn RAM, để dành 4G cho hệ thống & dịch vụ khác
        reservations:
          cpus: '2.0'
          memory: 8G
```

· Giải thích: Giới hạn này ngăn dịch vụ chiếm dụng toàn bộ tài nguyên, đảm bảo hệ điều hành và các tiến trình khác hoạt động mượt mà.

Ưu tiên 3: Tối ưu ChromaDB cho SSD & RAM

· Cấu hình ChromaDB (có thể đặt trong docker-compose.yml hoặc biến môi trường):
  ```yaml
  environment:
    - CHROMA_MEMORY_THRESHOLD=0.85 # Dừng nạp dữ liệu vào RAM khi đạt 85%
    - CHROMA_PERSIST_DIRECTORY=/chroma/data # Đảm bảo lưu trên volume SSD
  ```
· Lợi ích: ChromaDB sẽ tối ưu sử dụng bộ nhớ và tận dụng tốc độ của SSD.

Ưu tiên 4: Triển khai xử lý bất đồng bộ & Hàng đợi

· Vấn đề: Các thao tác thêm/xóa tài liệu số lượng lớn có thể chặn luồng phản hồi API.
· Giải pháp: Dùng thư viện như Celery hoặc RQ để xử lý các tác vụ nặng (nhận file, xử lý văn bản, tạo embedding) ở nền.

📊 Lộ Trình Triển Khai & Lưu Ý

Để triển khai hiệu quả, bạn nên làm theo thứ tự sau:

1. Thiết lập API Key: Đăng ký và lấy GEMINI_API_KEY từ Google AI Studio.
2. Tích hợp Cơ Bản: Cập nhật requirements.txt, tạo gemini_client.py và thử nghiệm gọi API đơn giản trước.
3. Tối Ưu Embedding: Chuyển collection trong ChromaDB sang dùng GoogleGenerativeAiEmbeddingFunction để giảm tải CPU ngay lập tức.
4. Xây dựng RAG: Hoàn thiện RAGProcessor trong ai_utils.py và endpoint /api/ask.
5. Điều Chỉnh Tài Nguyên: Cấu hình giới hạn Docker dựa trên việc theo dõi hiệu năng thực tế bằng lệnh docker stats.
6. Xử lý Bất đồng bộ (Nếu cần): Triển khai hàng đợi cho các tác vụ tốn thời gian khi số lượng người dùng tăng.

Những điểm cần lưu ý:

· Chi phí API: Sử dụng Gemini API sẽ phát sinh chi phí, nhưng rất thấp cho lượng truy vấn vừa phải. Hãy theo dõi trên Google Cloud Console.
· Độ trễ mạng: Câu trả lời sẽ phụ thuộc vào tốc độ mạng của bạn đến server Google.
· Dự phòng ngoại tuyến: Nếu mạng có vấn đề, hệ thống có thể chuyển sang chế độ chỉ tìm kiếm trong ChromaDB (không có phần trả lời tự nhiên từ Gemini).

Kiến trúc này cho phép bạn xây dựng một server AI với tính năng tìm kiếm và hỏi đáp thông minh, vượt qua giới hạn phần cứng cục bộ bằng cách sử dụng sức mạnh điện toán đám mây một cách thông minh.
