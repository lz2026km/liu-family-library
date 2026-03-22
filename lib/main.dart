import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fl_chart/fl_chart.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('books');
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '刘老大家庭书库',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown), useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class Book {
  final String id, title, author, location;
  final String? isbn, publisher, year, desc;
  final String status;
  final DateTime createdAt;
  Book({required this.id, required this.title, this.author = '', required this.location, this.isbn, this.publisher, this.year, this.desc, this.status = 'unread', DateTime? createdAt}) : createdAt = createdAt ?? DateTime.now();
  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'author': author, 'location': location, 'isbn': isbn, 'publisher': publisher, 'year': year, 'desc': desc, 'status': status, 'createdAt': createdAt.toIso8601String()};
  factory Book.fromMap(Map<String, dynamic> m) => Book(id: m['id'], title: m['title'], author: m['author'] ?? '', location: m['location'], isbn: m['isbn'], publisher: m['publisher'], year: m['year'], desc: m['desc'], status: m['status'] ?? 'unread', createdAt: m['createdAt'] != null ? DateTime.parse(m['createdAt']) : null);
}

class Db {
  static final Db _ = Db._i();
  Db._i();
  factory Db() => _;
  late Box _box;
  List<Book> all() => _box.values.map((e) => Book.fromMap(Map<String, dynamic>.from(e))).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  Future<void> add(Book b) async => await _box.put(b.id, b.toMap());
  Future<void> delete(String id) async => await _box.delete(id);
  List<Book> search(String q) { final l = q.toLowerCase(); return all().where((b) => b.title.toLowerCase().contains(l) || b.author.toLowerCase().contains(l) || b.location.toLowerCase().contains(l)).toList(); }
  Map<String, int> stats() { final books = all(); return {'total': books.length, 'unread': books.where((b) => b.status == 'unread').length, 'reading': books.where((b) => b.status == 'reading').length, 'finished': books.where((b) => b.status == 'finished').length}; }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Book> _books = [];
  @override
  void initState() { super.initState(); _load(); }
  void _load() => setState(() => _books = Db().all());
  
  @override
  Widget build(BuildContext context) {
    final s = Db().stats();
    return Scaffold(
      appBar: AppBar(title: const Text('刘老大家庭书库'), backgroundColor: Colors.brown.shade700, foregroundColor: Colors.white, actions: [
        IconButton(icon: const Icon(Icons.search), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchPage())).then((_) => _load())),
        IconButton(icon: const Icon(Icons.bar_chart), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsPage()))),
      ]),
      body: Column(children: [
        Container(width: double.infinity, margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.brown.shade600, Colors.brown.shade800]), borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [Column(children: [Text('${s['total']}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)), Text('总藏书', style: TextStyle(color: Colors.white70))]), Column(children: [Text('${s['reading']}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.orange.shade200)), Text('在读', style: TextStyle(color: Colors.white70))]), Column(children: [Text('${s['finished']}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green.shade200)), Text('已读', style: TextStyle(color: Colors.white70))])])),
        Expanded(child: _books.isEmpty ? const Center(child: Text('还没有书籍，点击右下角添加', style: TextStyle(color: Colors.grey))) : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _books.length, itemBuilder: (_, i) => Card(child: ListTile(leading: CircleAvatar(backgroundColor: Colors.brown.shade100, child: Text(_books[i].title[0], style: TextStyle(color: Colors.brown.shade700, fontWeight: FontWeight.bold))), title: Text(_books[i].title, maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text('${_books[i].author} · ${_books[i].location}'), trailing: Icon(_books[i].status == 'finished' ? Icons.check_circle : (_books[i].status == 'reading' ? Icons.auto_stories : Icons.circle_outlined), color: _books[i].status == 'finished' ? Colors.green : (_books[i].status == 'reading' ? Colors.orange : Colors.grey)), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(book: _books[i]))).then((_) => _load())))),
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPage())).then((_) => _load()), backgroundColor: Colors.brown.shade700, icon: const Icon(Icons.add), label: const Text('录入书籍')),
    );
  }
}

class AddPage extends StatefulWidget {
  const AddPage({super.key});
  @override
  State<AddPage> createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> {
  final _title = TextEditingController(), _author = TextEditingController(), _isbn = TextEditingController(), _location = TextEditingController();
  String _status = 'unread';
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('录入书籍'), backgroundColor: Colors.brown.shade700, foregroundColor: Colors.white, actions: [TextButton(onPressed: () async { if (_title.text.isEmpty || _location.text.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写书名和存放位置'))); return; } await Db().add(Book(id: DateTime.now().millisecondsSinceEpoch.toString(), title: _title.text, author: _author.text, isbn: _isbn.text.isEmpty ? null : _isbn.text, location: _location.text, status: _status)); if (mounted) Navigator.pop(context); }, child: const Text('保存', style: TextStyle(color: Colors.white, fontSize: 16)))]),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
        TextField(controller: _title, decoration: const InputDecoration(labelText: '书名 *', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _author, decoration: const InputDecoration(labelText: '作者', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _isbn, decoration: const InputDecoration(labelText: 'ISBN', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: _status, decoration: const InputDecoration(labelText: '阅读状态', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: 'unread', child: Text('未读')), DropdownMenuItem(value: 'reading', child: Text('在读')), DropdownMenuItem(value: 'finished', child: Text('已读'))], onChanged: (v) => setState(() => _status = v!)),
        const SizedBox(height: 12),
        TextField(controller: _location, decoration: const InputDecoration(labelText: '存放位置 *', border: OutlineInputBorder())),
      ])),
    );
  }
}

class DetailPage extends StatelessWidget {
  final Book book;
  const DetailPage({super.key, required this.book});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(book.title), backgroundColor: Colors.brown.shade700, foregroundColor: Colors.white, actions: [IconButton(icon: const Icon(Icons.delete), onPressed: () async { if (await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('确认删除'), content: Text('删除《${book.title}》？'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除', style: TextStyle(color: Colors.red)))])) == true) { await Db().delete(book.id); if (context.mounted) Navigator.pop(context); }})]),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(book.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text('作者: ${book.author}'), const SizedBox(height: 16), Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [Row(children: [Icon(Icons.location_on, color: Colors.brown.shade400), const SizedBox(width: 8), Text('位置: ${book.location}')]), if (book.isbn != null) Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [Icon(Icons.qr_code, color: Colors.brown.shade400), const SizedBox(width: 8), Text('ISBN: ${book.isbn}')]))])), if (book.desc != null) ...[const SizedBox(height: 16), const Text('简介', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text(book.desc!)])),
    );
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _ctrl = TextEditingController();
  List<Book> _results = [];
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('搜索'), backgroundColor: Colors.brown.shade700, foregroundColor: Colors.white), body: Column(children: [Padding(padding: const EdgeInsets.all(16), child: TextField(controller: _ctrl, onChanged: (q) => setState(() => _results = Db().search(q)), decoration: const InputDecoration(hintText: '搜索...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()))), Expanded(child: ListView.builder(itemCount: _results.length, itemBuilder: (_, i) => ListTile(title: Text(_results[i].title), subtitle: Text(_results[i].location), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(book: _results[i])))))]));
  }
}

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = Db().stats();
    return Scaffold(appBar: AppBar(title: const Text('统计'), backgroundColor: Colors.brown.shade700, foregroundColor: Colors.white), body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [SizedBox(height: 200, child: PieChart(PieChartData(sections: [PieChartSectionData(value: (s['unread'] ?? 0).toDouble(), color: Colors.grey, title: '未读'), PieChartSectionData(value: (s['reading'] ?? 0).toDouble(), color: Colors.orange, title: '在读'), PieChartSectionData(value: (s['finished'] ?? 0).toDouble(), color: Colors.green, title: '已读')]))), const SizedBox(height: 32), Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('📚 总藏书'), Text('${s['total']}', style: const TextStyle(fontWeight: FontWeight.bold))]), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('📖 在读'), Text('${s['reading']}', style: const TextStyle(fontWeight: FontWeight.bold))]), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('✅ 已读'), Text('${s['finished']}', style: const TextStyle(fontWeight: FontWeight.bold))])])))]));
  }
}