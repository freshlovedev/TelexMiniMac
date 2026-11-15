import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'controller.dart';
import 'text_tools.dart';
import 'widgets.dart';

class TextToolsPage extends StatefulWidget {
  const TextToolsPage({super.key, required this.controller});
  final AppController controller;
  @override
  State<TextToolsPage> createState() => _TextToolsPageState();
}

class _TextToolsPageState extends State<TextToolsPage> {
  final editor = TextEditingController();
  TextTool action = TextTool.nfc;
  bool busy = false;
  String message = '';
  static const labels = <TextTool, List<String>>{
    TextTool.nfc: ['Unicode NFC', 'Unicode NFC'],
    TextTool.withoutMarks: ['Bỏ dấu tiếng Việt', 'Remove Vietnamese marks'],
    TextTool.uppercase: ['CHỮ HOA', 'UPPERCASE'],
    TextTool.lowercase: ['chữ thường', 'lowercase'],
    TextTool.titleCase: ['Viết Hoa Từng Từ', 'Title Case'],
    TextTool.sentenceCase: ['Viết hoa đầu câu', 'Sentence case'],
    TextTool.cleanSpaces: ['Dọn khoảng trắng', 'Clean whitespace'],
    TextTool.markdown: ['Chuẩn hóa Markdown', 'Normalize Markdown'],
  };

  @override
  void initState() {super.initState();editor.addListener(_onEdit);}
  void _onEdit() {if(mounted)setState(() {});}
  @override
  void dispose() {editor.removeListener(_onEdit);editor.dispose();super.dispose();}

  Future<void> paste() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if(text == null) return;
    if(text.length > 60000) {
      setState(() => message = widget.controller.t(
        'Văn bản quá dài (tối đa 60.000 ký tự).',
        'Text exceeds the 60,000-character limit.'));
      return;
    }
    final range = editor.selection;
    final old = editor.text;
    if(range.isValid && !range.isCollapsed) {
      final before = old.substring(0, range.start);
      final after = old.substring(range.end);
      editor.value = TextEditingValue(
        text: before + text + after,
        selection: TextSelection.collapsed(offset: before.length + text.length));
    } else {
      editor.value = TextEditingValue(text:text,
        selection: TextSelection.collapsed(offset:text.length));
    }
    setState(() => message = widget.controller.t(
      'Đã dán theo yêu cầu. Không lưu văn bản vào bộ nhớ lâu dài.',
      'Pasted on request; the text is not saved to disk.'));
  }

  Future<void> transform() async {
    if(busy) return;
    final old = editor.text;
    if(old.length > 60000) return;
    final selection = editor.selection;
    final start = selection.isValid && !selection.isCollapsed ? selection.start : 0;
    final end = selection.isValid && !selection.isCollapsed ? selection.end : old.length;
    setState(() {busy=true;message='';});
    try {
      final transformed = await TextToolbox.apply(old.substring(start,end),action);
      if(!mounted)return;
      editor.value = TextEditingValue(
        text: old.substring(0,start)+transformed+old.substring(end),
        selection: TextSelection.collapsed(offset:start+transformed.length));
      setState(() => message = widget.controller.t(
        'Đã xử lý phần được chọn (hoặc toàn bộ văn bản).',
        'Transformed selection (or all text).'));
    } catch(e) {
      if(mounted)setState(() => message = e.toString());
    } finally {
      if(mounted)setState(() => busy=false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c=widget.controller;
    return PageFrame(
      controller:c,
      title:c.t('Công cụ xử lý văn bản','Quick Text Tools'),
      subtitle:c.t('Biến đổi văn bản offline. Chỉ xử lý phần mày chọn, không theo dõi clipboard.',
        'Private offline text transformations. Edit only selected content.'),
      child:SingleChildScrollView(child:Column(
        crossAxisAlignment:CrossAxisAlignment.stretch,
        children:[
          SurfaceCard(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Row(children:[
              const Icon(Icons.edit_note_rounded,color:teal),
              const SizedBox(width:10),
              Expanded(child:Text(c.t('Trình soạn thảo nhanh','Quick editor'),
                style:const TextStyle(fontSize:17,fontWeight:FontWeight.w800))),
            ]),
            const SizedBox(height:8),
            Text(c.t('Dán văn bản vào đây, có thể bôi đen một đoạn để chỉ xử lý đoạn đó.',
              'Paste text here; select a portion to transform only that portion.'),
              style:const TextStyle(fontSize:12,color:muted)),
            const SizedBox(height:10),
            TextField(
              key:const Key('text-tool-editor'),
              controller:editor,
              minLines:7,maxLines:12,
              decoration:InputDecoration(
                hintText:c.t('Dán văn bản hoặc gõ thử ở đây...',
                  'Paste or type a sample here...'),
              ),
            ),
            const SizedBox(height:12),
            Wrap(spacing:10,runSpacing:10,children:[
              SizedBox(width:250,child:DropdownButtonFormField<TextTool>(
                key:const Key('text-tool-mode'),
                initialValue:action,
                isExpanded:true,
                items:labels.entries.map((entry)=>DropdownMenuItem(
                  value:entry.key,
                  child:Text(c.englishUI?entry.value.last:entry.value.first,
                    maxLines:1,overflow:TextOverflow.ellipsis)))
                  .toList(),
                onChanged:(v)=>setState(() => action=v??TextTool.nfc),
              )),
              FilledButton.icon(
                key:const Key('text-tool-apply'),
                onPressed:busy?null:transform,
                icon:const Icon(Icons.auto_fix_high_rounded),
                label:Text(c.t('Áp dụng','Apply')),
              ),
              OutlinedButton.icon(onPressed:paste,
                icon:const Icon(Icons.content_paste_rounded),
                label:Text(c.t('Dán clipboard','Paste clipboard'))),
              OutlinedButton.icon(onPressed:editor.text.isEmpty?null:() async {
                await Clipboard.setData(ClipboardData(text:editor.text));
                if(mounted)setState(() => message=c.t('Đã sao chép.','Copied.'));
              }, icon:const Icon(Icons.copy_all_rounded),
                label:Text(c.t('Sao chép kết quả','Copy result'))),
              TextButton.icon(onPressed:(){
                editor.clear();
                setState(() {message='';});
              },icon:const Icon(Icons.delete_outline_rounded),
                label:Text(c.t('Xóa ô','Clear'))),
            ]),
            if(message.isNotEmpty)Padding(
              padding:const EdgeInsets.only(top:10),
              child:Text(message,style:const TextStyle(color:muted))),
          ])),
          const SizedBox(height:12),
          SurfaceCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(c.t('Chỉnh sửa văn bản đã bôi đen ngoài ứng dụng',
              'Editing a selection in another app'),
              style:const TextStyle(fontWeight:FontWeight.w700)),
            const SizedBox(height:8),
            Text(c.t('Chọn nội dung → Ctrl+C → mở Công cụ văn bản → Dán clipboard → Áp dụng → Sao chép kết quả → Ctrl+V vào ứng dụng ban đầu. Quy trình không cần quyền Accessibility hoặc đọc clipboard nền.',
              'Select text → Ctrl+C → Paste clipboard here → Apply → Copy result → Ctrl+V into the original app. No accessibility permission or background clipboard monitoring is needed.'),
              style:const TextStyle(color:muted,fontSize:12)),
          ])),
        ],
      )),
    );
  }
}
