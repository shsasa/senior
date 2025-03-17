import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(RestaurantAdminApp());
}

class RestaurantAdminApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Restaurant Admin Dashboard',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
      ),
      home: AdminDashboard(),
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('restaurant.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE dishes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        price REAL NOT NULL,
        category_id INTEGER,
        image_path TEXT,
        FOREIGN KEY (category_id) REFERENCES categories (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE staff (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        phone TEXT,
        approved INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_name TEXT NOT NULL,
        customer_phone TEXT NOT NULL,
        order_time TEXT NOT NULL,
        status TEXT NOT NULL,
        total_amount REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER,
        dish_id INTEGER,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,
        FOREIGN KEY (order_id) REFERENCES orders (id),
        FOREIGN KEY (dish_id) REFERENCES dishes (id)
      )
    ''');

    // Insert some default categories
    await db.insert('categories', {'name': 'Appetizers'});
    await db.insert('categories', {'name': 'Main Course'});
    await db.insert('categories', {'name': 'Desserts'});
    await db.insert('categories', {'name': 'Beverages'});
  }

  // Category methods
  Future<int> createCategory(Map<String, dynamic> category) async {
    final db = await instance.database;
    return await db.insert('categories', category);
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await instance.database;
    return await db.query('categories', orderBy: 'name');
  }

  Future<int> deleteCategory(int id) async {
    final db = await instance.database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // Dish methods
  Future<int> createDish(Map<String, dynamic> dish) async {
    final db = await instance.database;
    return await db.insert('dishes', dish);
  }

  Future<List<Map<String, dynamic>>> getDishes({int? categoryId}) async {
    final db = await instance.database;
    if (categoryId != null) {
      return await db.query('dishes',
          where: 'category_id = ?', whereArgs: [categoryId], orderBy: 'name');
    }
    return await db.query('dishes', orderBy: 'name');
  }

  Future<int> updateDish(Map<String, dynamic> dish) async {
    final db = await instance.database;
    return await db.update(
      'dishes',
      dish,
      where: 'id = ?',
      whereArgs: [dish['id']],
    );
  }

  Future<int> deleteDish(int id) async {
    final db = await instance.database;
    return await db.delete('dishes', where: 'id = ?', whereArgs: [id]);
  }

  // Staff methods
  Future<List<Map<String, dynamic>>> getPendingStaff() async {
    final db = await instance.database;
    return await db.query(
      'staff',
      where: 'approved = ?',
      whereArgs: [0],
    );
  }

  Future<List<Map<String, dynamic>>> getApprovedStaff() async {
    final db = await instance.database;
    return await db.query(
      'staff',
      where: 'approved = ?',
      whereArgs: [1],
    );
  }

  Future<int> approveStaff(int id) async {
    final db = await instance.database;
    return await db.update(
      'staff',
      {'approved': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> rejectStaff(int id) async {
    final db = await instance.database;
    return await db.delete(
      'staff',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Order methods
  Future<List<Map<String, dynamic>>> getOrders() async {
    final db = await instance.database;
    return await db.query('orders', orderBy: 'order_time DESC');
  }

  Future<List<Map<String, dynamic>>> getOrderItems(int orderId) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT oi.*, d.name as dish_name 
      FROM order_items oi
      JOIN dishes d ON oi.dish_id = d.id
      WHERE oi.order_id = ?
    ''', [orderId]);
  }
}

class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [
    OrdersPage(),
    MenuPage(),
    StaffManagementPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant Admin Dashboard'),
        elevation: 2,
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'Menu',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Staff',
          ),
        ],
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}

class OrdersPage extends StatefulWidget {
  @override
  _OrdersPageState createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final orders = await DatabaseHelper.instance.getOrders();
    setState(() {
      _orders = orders;
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: _orders.isEmpty
          ? const Center(child: Text('No orders found'))
          : ListView.builder(
              itemCount: _orders.length,
              itemBuilder: (context, index) {
                final order = _orders[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text(
                        'Order #${order['id']} - ${order['customer_name']}'),
                    subtitle: Text(
                        'Status: ${order['status']} • Total: \$${order['total_amount'].toStringAsFixed(2)}'),
                    trailing: Text(order['order_time']),
                    onTap: () => _showOrderDetails(order),
                  ),
                );
              },
            ),
    );
  }

  void _showOrderDetails(Map<String, dynamic> order) async {
    final orderItems = await DatabaseHelper.instance.getOrderItems(order['id']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order #${order['id']} Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${order['customer_name']}'),
            Text('Phone: ${order['customer_phone']}'),
            Text('Order Time: ${order['order_time']}'),
            Text('Status: ${order['status']}'),
            const Divider(),
            const Text('Items:'),
            ...orderItems.map((item) => Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                      '${item['quantity']}x ${item['dish_name']} - \$${item['price'].toStringAsFixed(2)}'),
                )),
            const Divider(),
            Text('Total: \$${order['total_amount'].toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class MenuPage extends StatefulWidget {
  @override
  _MenuPageState createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  List<Map<String, dynamic>> _categories = [];
  int? _selectedCategoryId;
  List<Map<String, dynamic>> _dishes = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await DatabaseHelper.instance.getCategories();
    setState(() {
      _categories = categories;
      if (categories.isNotEmpty && _selectedCategoryId == null) {
        _selectedCategoryId = categories[0]['id'];
        _loadDishes(_selectedCategoryId!);
      }
    });
  }

  Future<void> _loadDishes(int categoryId) async {
    final dishes =
        await DatabaseHelper.instance.getDishes(categoryId: categoryId);
    setState(() {
      _dishes = dishes;
      _selectedCategoryId = categoryId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Menu Management',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ElevatedButton(
                onPressed: _showAddCategoryDialog,
                child: const Text('Add Category'),
              ),
            ],
          ),
        ),
        // Category tabs
        Container(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              final isSelected = category['id'] == _selectedCategoryId;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(category['name']),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      _loadDishes(category['id']);
                    }
                  },
                ),
              );
            },
          ),
        ),
        // Add dish button
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Dish'),
                onPressed: _selectedCategoryId != null
                    ? () => _showAddDishDialog(_selectedCategoryId!)
                    : null,
              ),
            ],
          ),
        ),
        // Dishes list
        Expanded(
          child: _dishes.isEmpty
              ? const Center(child: Text('No dishes in this category'))
              : ListView.builder(
                  itemCount: _dishes.length,
                  itemBuilder: (context, index) {
                    final dish = _dishes[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        title: Text(dish['name']),
                        subtitle: Text('\$${dish['price'].toStringAsFixed(2)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showEditDishDialog(dish),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _showDeleteDishDialog(dish),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showAddCategoryDialog() {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Add New Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await DatabaseHelper.instance.createCategory({
                  'name': controller.text.trim(),
                });
                Navigator.pop(context);
                _loadCategories();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddDishDialog(int categoryId) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Dish'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Dish Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'Price',
                  border: OutlineInputBorder(),
                  prefixText: '\$',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty &&
                  priceController.text.trim().isNotEmpty) {
                try {
                  final price = double.parse(priceController.text.trim());
                  await DatabaseHelper.instance.createDish({
                    'name': nameController.text.trim(),
                    'description': descriptionController.text.trim(),
                    'price': price,
                    'category_id': categoryId,
                  });
                  Navigator.pop(context);
                  _loadDishes(categoryId);
                } catch (e) {
                  // Handle invalid price format
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditDishDialog(Map<String, dynamic> dish) {
    final nameController = TextEditingController(text: dish['name']);
    final descriptionController =
        TextEditingController(text: dish['description'] ?? '');
    final priceController =
        TextEditingController(text: dish['price'].toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Dish'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Dish Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'Price',
                  border: OutlineInputBorder(),
                  prefixText: '\$',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty &&
                  priceController.text.trim().isNotEmpty) {
                try {
                  final price = double.parse(priceController.text.trim());
                  await DatabaseHelper.instance.updateDish({
                    'id': dish['id'],
                    'name': nameController.text.trim(),
                    'description': descriptionController.text.trim(),
                    'price': price,
                    'category_id': dish['category_id'],
                  });
                  Navigator.pop(context);
                  _loadDishes(dish['category_id']);
                } catch (e) {
                  // Handle invalid price format
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDishDialog(Map<String, dynamic> dish) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Dish'),
        content: Text('Are you sure you want to delete "${dish['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              await DatabaseHelper.instance.deleteDish(dish['id']);
              Navigator.pop(context);
              _loadDishes(dish['category_id']);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class StaffManagementPage extends StatefulWidget {
  @override
  _StaffManagementPageState createState() => _StaffManagementPageState();
}

class _StaffManagementPageState extends State<StaffManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _pendingStaff = [];
  List<Map<String, dynamic>> _approvedStaff = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStaffData();
  }

  Future<void> _loadStaffData() async {
    final pendingStaff = await DatabaseHelper.instance.getPendingStaff();
    final approvedStaff = await DatabaseHelper.instance.getApprovedStaff();
    setState(() {
      _pendingStaff = pendingStaff;
      _approvedStaff = approvedStaff;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'Pending Approval'),
            const Tab(text: 'Approved Staff'),
          ],
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.orange,
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Pending staff tab
              RefreshIndicator(
                onRefresh: _loadStaffData,
                child: _pendingStaff.isEmpty
                    ? const Center(child: Text('No pending staff registrations'))
                    : ListView.builder(
                        itemCount: _pendingStaff.length,
                        itemBuilder: (context, index) {
                          final staff = _pendingStaff[index];
                          return Card(
                            margin: const EdgeInsets.all(8),
                            child: ListTile(
                              title: Text(staff['name']),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Email: ${staff['email']}'),
                                  if (staff['phone'] != null)
                                    Text('Phone: ${staff['phone']}'),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check_circle,
                                        color: Colors.green),
                                    onPressed: () =>
                                        _approveStaffMember(staff['id']),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.cancel, color: Colors.red),
                                    onPressed: () =>
                                        _rejectStaffMember(staff['id']),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Approved staff tab
              RefreshIndicator(
                onRefresh: _loadStaffData,
                child: _approvedStaff.isEmpty
                    ? const Center(child: Text('No approved staff members'))
                    : ListView.builder(
                        itemCount: _approvedStaff.length,
                        itemBuilder: (context, index) {
                          final staff = _approvedStaff[index];
                          return Card(
                            margin: const EdgeInsets.all(8),
                            child: ListTile(
                              title: Text(staff['name']),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Email: ${staff['email']}'),
                                  if (staff['phone'] != null)
                                    Text('Phone: ${staff['phone']}'),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _approveStaffMember(int staffId) async {
    await DatabaseHelper.instance.approveStaff(staffId);
    _loadStaffData();
  }

  Future<void> _rejectStaffMember(int staffId) async {
    await DatabaseHelper.instance.rejectStaff(staffId);
    _loadStaffData();
  }
}