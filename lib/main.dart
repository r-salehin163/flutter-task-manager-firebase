import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:task_manager/notification_service.dart';
import 'firebase_options.dart';
import 'package:intl/intl.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Notifications
  await NotificationService.init();
  
  runApp(const MaterialApp(home: AuthWrapper(), debugShowCheckedModeBanner: false));
}

// --- AUTH WRAPPER: Decides if we show Login or Task Manager ---
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) return const TaskManagerScreen();
        return const LoginScreen();
      },
    );
  }
}

// --- LOGIN SCREEN ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool isLogin = true;

  void _submit() async {
    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: _email.text, password: _pass.text);
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _email.text, password: _pass.text);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(isLogin ? "Welcome Back" : "Create Account", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(controller: _email, decoration: const InputDecoration(labelText: "Email")),
            TextField(controller: _pass, decoration: const InputDecoration(labelText: "Password"), obscureText: true),
            const SizedBox(height: 30),
            ElevatedButton(onPressed: _submit, child: Text(isLogin ? "Login" : "Register")),
            TextButton(onPressed: () => setState(() => isLogin = !isLogin), child: Text(isLogin ? "Need an account? Register" : "Have an account? Login"))
          ],
        ),
      ),
    );
  }
}

// --- TASK MANAGER (PRIVATE) ---
class TaskManagerScreen extends StatefulWidget {
  const TaskManagerScreen({super.key});

  @override
  State<TaskManagerScreen> createState() => _TaskManagerScreenState();
}

class _TaskManagerScreenState extends State<TaskManagerScreen> {
  final TextEditingController _taskController = TextEditingController();
  final String userId = FirebaseAuth.instance.currentUser!.uid;
  
  // Default values for new tasks
  String _selectedPriority = 'Medium'; 
  DateTime? _selectedDate;

  // Helper to get color based on priority
  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High': return Colors.redAccent;
      case 'Medium': return Colors.orangeAccent;
      case 'Low': return Colors.greenAccent;
      default: return Colors.grey;
    }
  }

  void _showAddTaskSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder( // Use StatefulBuilder to update UI inside the sheet
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _taskController, autofocus: true, decoration: const InputDecoration(hintText: "Task Name")),
              const SizedBox(height: 20),
              
              // Priority Selector
              const Text("Priority"),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['Low', 'Medium', 'High'].map((p) => ChoiceChip(
                  label: Text(p),
                  selected: _selectedPriority == p,
                  onSelected: (val) => setSheetState(() => _selectedPriority = p),
                )).toList(),
              ),
              
              // Date Picker Button
              TextButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(_selectedDate == null ? "Set Due Date" : "Due: ${_selectedDate!.toLocal()}".split(' ')[0]),
                onPressed: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setSheetState(() => _selectedDate = picked);
                },
              ),
              
              ElevatedButton(
                onPressed: () {
                  if (_taskController.text.isNotEmpty) {
                    FirebaseFirestore.instance.collection('tasks').add({
                      'title': _taskController.text,
                      'isDone': false,
                      'userId': userId,
                      'priority': _selectedPriority,
                      'dueDate': _selectedDate != null ? Timestamp.fromDate(_selectedDate!) : null,
                      'timestamp': FieldValue.serverTimestamp(),
                    });
                    _taskController.clear();
                    _selectedDate = null;
                    Navigator.pop(context);
                  }
                },
                child: const Text("Add Task"),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Task Manager"),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut())],
      ),
      body: StreamBuilder(
        // 1. We removed .orderBy to bypass index requirements for testing
        stream: FirebaseFirestore.instance
          .collection('tasks')
          .where('userId', isEqualTo: userId)
          .orderBy('priority') // Keep ordering by priority
          .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          // 2. This will show you the REAL error on your screen if it fails
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)),
              ),
            );
          }

          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No tasks found for your user ID. Try adding one!"));
          }
          
          return ListView(
            padding: const EdgeInsets.all(10),
            children: snapshot.data!.docs.map((doc) {
              // ... keep your existing Card UI code here ...
              String priority = doc['priority'] ?? 'Medium';
              Timestamp? dateStamp = doc['dueDate'];
              
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: _getPriorityColor(priority), width: 4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  title: Text(doc['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(dateStamp != null 
                      ? "Due: ${DateFormat('yMMMd').format(dateStamp.toDate())}" 
                      : "No due date",
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  leading: Checkbox(
                    value: doc['isDone'],
                    onChanged: (v) => doc.reference.update({'isDone': v}),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => doc.reference.delete(),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: _showAddTaskSheet, child: const Icon(Icons.add)),
    );
  }
}