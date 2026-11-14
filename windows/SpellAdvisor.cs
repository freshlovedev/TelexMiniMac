using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;
using System.Linq;

namespace TelexMini
{
    // Opt-in suggestion only. Never hooks or automatically replaces user text.
    internal static class SpellAdvisor
    {
        const string Terms=@"kiểu nhiều vậy chạy xuống người tiếng việt được không những chúng mình bạn tôi hôm nay ngày mai hôm qua buổi sáng buổi chiều buổi tối cảm ơn xin chào tạm biệt thành công thất bại chương trình máy tính bàn phím soạn thảo văn bản ứng dụng thông tin thông minh câu chuyện thời gian công việc học sinh sinh viên giáo viên công nghệ phát triển thiết kế tài liệu hướng dẫn cập nhật tài khoản đăng nhập mật khẩu thay đổi hệ thống chữ viết tiếng anh ngôn ngữ phần mềm trang web hình ảnh video tải xuống dữ liệu bảo mật kết nối internet người dùng nhanh chậm chính xác kiểm tra lỗi sửa hoàn thành tiếp tục bắt đầu kết thúc trong ngoài trên dưới bên cạnh trái phải ngày tháng năm giờ phút giây vui vẻ hạnh phúc gia đình bạn bè công ty dự án sản phẩm dịch vụ trường học bệnh viện trung tâm cửa hàng chiếc điện thoại thành phố quê hương sức khỏe niềm vui yêu thương lựa chọn ưu tiên giải quyết đề xuất thường xuyên khả năng hoàn thiện nguyên âm dấu thanh định dạng chuyển đổi cài đặt";
        static readonly string[] Words=Terms.Split(' ');
        static int Distance(string left,string right) {
            if(Math.Abs(left.Length-right.Length)>2) return 3;
            var previous=new int[right.Length+1];
            var current=new int[right.Length+1];
            for(int i=0;i<=right.Length;i++)previous[i]=i;
            for(int i=1;i<=left.Length;i++) {
                current[0]=i;
                for(int j=1;j<=right.Length;j++) {
                    int cost=left[i-1]==right[j-1]?0:1;
                    current[j]=Math.Min(Math.Min(current[j-1]+1,previous[j]+1),previous[j-1]+cost);
                }
                var temp=previous;previous=current;current=temp;
            }
            return previous[right.Length];
        }
        internal static string[] Suggest(string word,int limit=3) {
            if(string.IsNullOrWhiteSpace(word)||word.Length>48||limit<=0)return new string[0];
            string normalized=word.Trim().ToLowerInvariant().Normalize(NormalizationForm.FormC);
            return Words.Select(w=>new {Word=w,Score=Distance(normalized,w)})
                .Where(x=>x.Score>0&&x.Score<=2)
                .OrderBy(x=>x.Score).ThenBy(x=>x.Word.Length).ThenBy(x=>x.Word)
                .Take(limit).Select(x=>x.Word).ToArray();
        }
    }
}
