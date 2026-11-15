import 'package:flutter/material.dart';
import 'controller.dart';
import 'widgets.dart';

// Real editable Flutter field, no key logs or typing-content persistence.
class TypingLabPage extends StatefulWidget {
  const TypingLabPage({super.key, required this.controller});
  final AppController controller;
  @override
  State<TypingLabPage> createState() => _TypingLabPageState();
}

class _LabCase {
  const _LabCase(this.typed, this.expected, this.note);
  final String typed, expected, note;
}

class _TypingLabPageState extends State<TypingLabPage> {
  static const cases = <_LabCase>[
    _LabCase('w','ư','Standalone Telex w'),
    _LabCase('now','nơ','Vietnamese nơ'),
    _LabCase('tieengs','tiếng','Tone placement'),
    _LabCase('chayj','chạy','Tone j'),
    _LabCase('boons','bốn','Repeated vowel'),
    _LabCase('been','bên','Vietnamese priority'),
    _LabCase('boost','boost','English protection'),
    _LabCase('parameter','parameter','Software vocabulary'),
    _LabCase('exe','exe','English executable'),
    _LabCase('ddang','đang','Double d'),
  ];
  final field=TextEditingController();
  final results=<int,bool>{};
  int index=0;
  String hint='';
  DateTime? started;
  Duration? elapsed;

  @override
  void dispose(){field.dispose();super.dispose();}

  void check(){
    final ok=field.text.trim()==cases[index].expected;
    setState((){
      results[index]=ok;
      elapsed=started==null?null:DateTime.now().difference(started!);
      hint=ok?widget.controller.t('Đạt','Pass'):
        widget.controller.t('Chưa đúng kết quả mong đợi','Does not match expected output');
    });
  }
  void choose(int next){
    setState((){index=next;field.clear();hint='';started=null;elapsed=null;});
  }

  @override
  Widget build(BuildContext context){
    final c=widget.controller;
    final sample=cases[index];
    final passed=results.values.where((v)=>v).length;
    return PageFrame(controller:c,
      title:'Typing Lab',
      subtitle:c.t('Tự kiểm tra bằng bàn phím Windows thật; không lưu nội dung gõ.',
        'Practice with a real Windows keyboard; typed content is never logged.'),
      child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        SurfaceCard(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Row(children:[
            const Icon(Icons.keyboard_alt_outlined,color:teal),
            const SizedBox(width:10),
            Expanded(child:Text(c.t('Bài kiểm tra Anh–Việt','Bilingual input test'),
              style:const TextStyle(fontWeight:FontWeight.w800,fontSize:17))),
            Text('$passed/${cases.length}',
              style:const TextStyle(fontWeight:FontWeight.w700)),
          ]),
          const SizedBox(height:10),
          LinearProgressIndicator(value:results.length/cases.length,
            backgroundColor:Colors.grey.shade200),
          const SizedBox(height:12),
          Text(c.t('Chuỗi phím cần gõ','Physical keys to type'),
            style:const TextStyle(color:muted,fontSize:12)),
          SelectableText(sample.typed,
            style:const TextStyle(fontSize:25,fontWeight:FontWeight.w800)),
          const SizedBox(height:6),
          Text(c.t('Kết quả mong đợi','Expected result'),
            style:const TextStyle(color:muted,fontSize:12)),
          Text(sample.expected,style:const TextStyle(
            fontSize:27,fontWeight:FontWeight.w700,color:teal)),
          const SizedBox(height:9),
          Text(sample.note,style:const TextStyle(color:muted,fontSize:12)),
          const SizedBox(height:15),
          TextField(
            key:const Key('typing-lab-input'),
            controller:field,
            onChanged:(value){
              if(started==null && value.isNotEmpty)started=DateTime.now();
              if(hint.isNotEmpty)setState((){hint='';});
            },
            decoration:InputDecoration(
              hintText:c.t('Gõ thử tại đây','Type in this field'),
              helperText:c.t('Giữ chế độ Telex/Balanced.',
                'Use Telex/Balanced mode.'),
            ),
          ),
          const SizedBox(height:14),
          Wrap(spacing:8,runSpacing:8,children:[
            FilledButton.icon(key:const Key('typing-lab-check'),
              onPressed:check,icon:const Icon(Icons.check_circle_outline),
              label:Text(c.t('Kiểm tra','Check'))),
            OutlinedButton.icon(onPressed:(){
              field.clear();
              setState((){started=null;elapsed=null;hint='';});
            },icon:const Icon(Icons.restart_alt),
              label:Text(c.t('Thử lại','Retry'))),
            OutlinedButton.icon(
              key:const Key('typing-lab-next'),
              onPressed:()=>choose((index+1)%cases.length),
              icon:const Icon(Icons.arrow_forward),
              label:Text(c.t('Bài tiếp','Next case'))),
          ]),
          if(hint.isNotEmpty)Padding(padding:const EdgeInsets.only(top:10),
            child:Text(hint,style:TextStyle(fontWeight:FontWeight.w700,
              color:results[index]==true?teal:Colors.deepOrange))),
          if(elapsed!=null)Text('${c.t('Thời gian thao tác: ', 'Attempt duration: ')}${elapsed!.inMilliseconds} ms',
            style:const TextStyle(color:muted,fontSize:11)),
        ])),
        const SizedBox(height:12),
        SurfaceCard(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Text(c.t('10 tình huống hồi quy quan trọng','10 critical regression scenarios'),
            style:const TextStyle(fontWeight:FontWeight.w800)),
          const SizedBox(height:9),
          Wrap(spacing:8,runSpacing:8,children:[
            for(var i=0;i<cases.length;i++)
              ActionChip(
                key:Key('typing-lab-case-$i'),
                backgroundColor:results[i]==true?const Color(0xFFE0F7EC):null,
                avatar:Icon(results[i]==true?Icons.check_circle:
                  results[i]==false?Icons.error_outline:Icons.keyboard,
                  size:16,color:results[i]==true?teal:muted),
                label:Text(cases[i].typed),
                onPressed:()=>choose(i),
              ),
          ]),
          const SizedBox(height:8),
          Text(c.t('Đây là kiểm tra bằng tay, không phải độ trễ phím-đến-màn-hình p95/p99.',
              'Manual typing checks, not key-to-screen p95/p99 latency benchmarks.'),
            style:const TextStyle(color:muted,fontSize:11)),
        ])),
      ])),
    );
  }
}
