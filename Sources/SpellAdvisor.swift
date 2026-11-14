import Foundation

/// Deliberately small, local spelling helper for explicit user requests.
/// No automatic insertion or logging of typed words.
enum SpellAdvisor {
    static let terms="kiểu nhiều vậy chạy xuống người tiếng việt được không những chúng mình bạn tôi hôm nay ngày mai hôm qua buổi sáng buổi chiều buổi tối cảm ơn xin chào tạm biệt thành công thất bại chương trình máy tính bàn phím soạn thảo văn bản ứng dụng thông tin thông minh câu chuyện thời gian công việc học sinh sinh viên giáo viên công nghệ phát triển thiết kế tài liệu hướng dẫn cập nhật tài khoản đăng nhập mật khẩu thay đổi hệ thống chữ viết tiếng anh ngôn ngữ phần mềm trang web hình ảnh video tải xuống dữ liệu bảo mật kết nối internet người dùng nhanh chậm chính xác kiểm tra lỗi sửa hoàn thành tiếp tục bắt đầu kết thúc trong ngoài trên dưới bên cạnh trái phải ngày tháng năm giờ phút giây vui vẻ hạnh phúc gia đình bạn bè công ty dự án sản phẩm dịch vụ trường học bệnh viện trung tâm cửa hàng chiếc điện thoại thành phố quê hương sức khỏe niềm vui yêu thương lựa chọn ưu tiên giải quyết đề xuất thường xuyên khả năng hoàn thiện nguyên âm dấu thanh định dạng chuyển đổi cài đặt"
        .split(separator:" ").map(String.init)
    private static func distance(_ a:String,_ b:String)->Int {
        let x=Array(a),y=Array(b)
        if abs(x.count-y.count)>2{return 3}
        var previous=Array(0...y.count)
        for i in 1...x.count {
            var current=[i]+Array(repeating:0,count:y.count)
            if !y.isEmpty {
                for j in 1...y.count {
                    current[j]=min(current[j-1]+1,previous[j]+1,
                                   previous[j-1]+(x[i-1]==y[j-1] ? 0 : 1))
                }
            }
            previous=current
        }
        return previous[y.count]
    }
    static func suggest(_ raw:String,limit:Int=3)->[String] {
        let normalized=raw.trimmingCharacters(in:.whitespacesAndNewlines)
            .lowercased().precomposedStringWithCanonicalMapping
        guard !normalized.isEmpty,normalized.count<=48,limit>0 else{return []}
        return terms.map {($0,distance(normalized,$0))}
            .filter {$0.1>0 && $0.1<=2}
            .sorted {l,r in
                if l.1 != r.1 {return l.1<r.1}
                if l.0.count != r.0.count{return l.0.count<r.0.count}
                return l.0<r.0
            }
            .prefix(limit).map {$0.0}
    }
}
