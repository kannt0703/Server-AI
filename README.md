# Server-AI
Tổng hợp kinh nghiệm gỡ lỗi
Dưới đây là tổng hợp các dòng lệnh kiểm tra và khắc phục sự cố mà chúng ta đã sử dụng, được nhóm theo mục đích:
🛠 Lệnh Kiểm tra Trạng thái Hệ thống và Docker
Những lệnh này giúp theo dõi tài nguyên và trạng thái các dịch vụ của bạn:
Xem thống kê tài nguyên (CPU, RAM, I/O) theo thời gian thực:
bash
docker stats
# Hoặc với định dạng bảng gọn gàng hơn:
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
Hãy thận trọng khi sử dụng mã.

Xem thông tin I/O (tốc độ đọc/ghi ổ cứng) trên máy chủ:
bash
iostat -xz 1
Hãy thận trọng khi sử dụng mã.

Xem danh sách các model đã tải xuống:
bash
docker exec -it ai-engine ollama list
Hãy thận trọng khi sử dụng mã.

Kiểm tra model nào đang được load trong RAM:
bash
docker exec -it ai-engine ollama ps
Hãy thận trọng khi sử dụng mã.

Chạy model AI trực tiếp trong container (test tốc độ CPU):
bash
docker exec -it ai-engine ollama run llama3.2:3b "Tại sao bạn chạy chậm thế?"
Hãy thận trọng khi sử dụng mã.

🌍 Lệnh Kiểm tra và Sửa lỗi Mạng/Kết nối
Kiểm tra kết nối Internet từ bên trong container:
bash
docker run -it --rm alpine:latest wget -qS --spider https://google.com
Hãy thận trọng khi sử dụng mã.

Ping từ container đến máy chủ Host:
bash
# Thay <IP_CUA_BAN> bằng IP thực tế, ví dụ 192.168.1.244
docker run -it --rm alpine:latest ping -c 4 <IP_CUA_BAN>
Hãy thận trọng khi sử dụng mã.

⚙️ Lệnh Quản lý Docker Compose và Logs
Những lệnh này dùng để khởi động lại dịch vụ và tìm lỗi trong logs:
Tắt và gỡ bỏ toàn bộ services:
bash
docker compose down
Hãy thận trọng khi sử dụng mã.

Khởi động lại services ở chế độ nền:
bash
docker compose up -d
Hãy thận trọng khi sử dụng mã.

Xem logs theo thời gian thực để tìm lỗi (lọc bỏ các dòng "200 OK"):
bash
docker logs -f ai-gateway | grep -v " 200 OK"
Hãy thận trọng khi sử dụng mã.

Xóa sạch thư mục dữ liệu ChromaDB (để fix lỗi NotFoundError):
bash
rm -rf ./database/data/*
Hãy thận trọng khi sử dụng mã.

Bây giờ hệ thống của bạn đã ổn định. Bạn có muốn lưu các lệnh này vào một file script tự động để tiện sử dụng lần sau không?
