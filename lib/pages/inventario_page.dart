import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class InventarioPage extends StatefulWidget {
  const InventarioPage({Key? key}) : super(key: key);

  @override
  _InventarioPageState createState() => _InventarioPageState();
}

class _InventarioPageState extends State<InventarioPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'Todos';
  List<String> _filterOptions = ['Todos'];

  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];

  final String baseUrl = 'https://modelo-server.vercel.app/api/v1';
  double availableMoney = 0.0;
  double ingresos = 0.0;
  double egresos = 0.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterProducts);
    _loadCategorias();
    _loadProductos();
    _fetchSaldo();
  }

  Future<void> _loadCategorias() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/categorias'));
      if (response.statusCode == 200) {
        final List<dynamic> categorias = json.decode(response.body);
        // Usar Set para eliminar duplicados
        final Set<String> categoriasUnicas = {
          ...categorias.map((c) => c['Nombre'].toString())
        };
        setState(() {
          _filterOptions = categoriasUnicas.toList()
            ..sort();
          _filterOptions.insert(0, 'Todos'); // Insertar "Todos" al inicio
        });
      }
    } catch (e) {
      _showErrorDialog('Error al cargar categorías');
    }
  }

  Future<void> _loadProductos() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await http.get(Uri.parse('$baseUrl/productos'));
      if (response.statusCode == 200) {
        final List<dynamic> productos = json.decode(response.body);

        // Usar un Map temporal para detectar y eliminar duplicados por ID
        final Map<int, Map<String, dynamic>> productosUnicos = {};

        for (var p in productos) {
          final id = p['IDProductos'];
          if (!productosUnicos.containsKey(id)) {
            productosUnicos[id] = {
              'id': id,
              'producto': p['Nombre'],
              'categoria': p['Categoria'],
              'stock': p['Stock'],
              'precio': p['Precio'].toDouble(),
              'precioCompra': p['PrecioDeCompra'].toDouble(),
            };
          }
        }

        setState(() {
          // Convertir el Map de productos únicos a List
          _allProducts = productosUnicos.values.toList();
          _filterProducts();
        });
      }
    } catch (e) {
      _showErrorDialog('Error al cargar productos');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchSaldo() async {
    final String baseUrl = 'https://modelo-server.vercel.app/api/v1';
    final String saldoEndpoint = '/saldo';

    try {
      final response = await http.get(Uri.parse('$baseUrl$saldoEndpoint'));

      if (response.statusCode == 200) {
        // Verifica la respuesta antes de intentar decodificarla
        final dynamic data = json.decode(response.body);

        // Agrega un log para ver qué tipo de datos estás recibiendo
        print('Respuesta recibida: $data');

        // Cambia la verificación para aceptar un objeto en lugar de una lista
        if (data is Map<String, dynamic> && data.containsKey('baseSaldo')) {
          setState(() {
            availableMoney = data['baseSaldo'].toDouble();
            ingresos = data['totalIngresos'].toDouble();
            egresos = data['totalEgresos'].toDouble();
            _isLoading = false;
          });
        } else {
          throw Exception('Formato inesperado o campo "saldo" no encontrado');
        }
      } else {
        throw Exception('Failed to load saldo');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar el saldo: $e')),
      );
    }
  }

  void _sortProducts() {
    _filteredProducts.sort((a, b) {
      int nameComparison = a['producto'].compareTo(b['producto']);
      if (nameComparison != 0) {
        return nameComparison;
      }
      return a['categoria'].compareTo(b['categoria']);
    });
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _allProducts.where((product) {
        final matchesQuery =
            product['producto'].toString().toLowerCase().contains(query) ||
                product['categoria'].toString().toLowerCase().contains(query) ||
                product['precio'].toString().contains(query) ||
                product['stock'].toString().contains(query);

        final matchesCategory = _selectedFilter == 'Todos' ||
            product['categoria'] == _selectedFilter;

        return matchesQuery && matchesCategory;
      }).toList();
      _sortProducts();
    });
  }

  Map<String, List<Map<String, dynamic>>> _groupProductsByCategory() {
    Map<String, List<Map<String, dynamic>>> groupedProducts = {};

    if (_selectedFilter != 'Todos') {
      groupedProducts[_selectedFilter] = _filteredProducts;
    } else {
      for (var product in _filteredProducts) {
        String category = product['categoria'];
        if (!groupedProducts.containsKey(category)) {
          groupedProducts[category] = [];
        }
        groupedProducts[category]!.add(product);
      }
    }

    return groupedProducts;
  }

  Future<void> _eliminarProducto(Map<String, dynamic> producto) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/productos/${producto['id']}'),
      );

      if (response.statusCode == 200) {
        setState(() {
          _allProducts.removeWhere((p) => p['id'] == producto['id']);
          _filterProducts();
        });
      } else {
        _showErrorDialog('Error al eliminar el producto');
      }
    } catch (e) {
      _showErrorDialog('Error de conexión al eliminar el producto');
    }
  }

  Future<void> _actualizarProducto(Map<String, dynamic> producto, String nombre,
      String categoria, String precio, String stock) async {
    setState(() {
      _isLoading = true;
    });

    final productoExistente = _allProducts.any((p) =>
    p['producto'].toLowerCase() == nombre.toLowerCase() &&
        p['id'] != producto['id']);

    if (productoExistente) {
      _showErrorDialog('Ya existe otro producto con este nombre');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/productos/${producto['id']}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'nombre': nombre,
          'categoria': categoria,
          'stock': int.parse(stock),
          'precio': double.parse(precio),
        }),
      );

      if (response.statusCode == 200) {
        await _loadProductos();
      } else {
        _showErrorDialog('Error al actualizar el producto');
      }
    } catch (e) {
      _showErrorDialog('Error de conexión al actualizar el producto');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _agregarProducto(String nombre, String categoria, String precio,
      String stock) async {
    // Verificar si ya existe un producto con el mismo nombre
    final productoExistente = _allProducts.any(
            (p) => p['producto'].toLowerCase() == nombre.toLowerCase());

    if (productoExistente) {
      _showErrorDialog('Ya existe un producto con este nombre');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/productosinsert'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'nombre': nombre,
          'categoria': categoria,
          'stock': int.parse(stock),
          'precio': double.parse(precio),
        }),
      );

      if (response.statusCode == 201) {
        await _loadProductos();
      } else {
        _showErrorDialog('Error al agregar el producto');
      }
    } catch (e) {
      _showErrorDialog('Error de conexión al agregar el producto');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  Widget _buildProductTable(List<Map<String, dynamic>> products,
      bool isSmallScreen) {
    double productWidth = isSmallScreen ? 100 : 200;
    double stockWidth = isSmallScreen ? 50 : 100;
    double priceWidth = isSmallScreen ? 50 : 100;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery
              .of(context)
              .size
              .width,
        ),
        child: DataTable(
          columnSpacing: isSmallScreen ? 20 : 56.0,
          horizontalMargin: isSmallScreen ? 12 : 24.0,
          columns: [
            DataColumn(
              label: SizedBox(
                width: productWidth,
                child: Text(
                  'Producto',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              tooltip: 'Nombre del producto',
            ),
            DataColumn(
              label: SizedBox(
                width: stockWidth,
                child: Text(
                  'Stock',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              tooltip: 'Cantidad disponible',
              numeric: true,
            ),
            DataColumn(
              label: SizedBox(
                width: priceWidth,
                child: Text(
                  'Precio',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              tooltip: 'Precio unitario',
              numeric: true,
            ),
            const DataColumn(
              label: SizedBox(
                width: 48,
                child: Text(''),
              ),
            ),
          ],
          rows: products.map((producto) {
            return DataRow(
              cells: [
                DataCell(
                  Container(
                    width: productWidth,
                    child: Text(
                      producto['producto'],
                      style: TextStyle(fontSize: isSmallScreen ? 13 : 15),
                      maxLines: null,
                      softWrap: true,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: stockWidth,
                    child: Text(
                      producto['stock'].toString(),
                      style: TextStyle(fontSize: isSmallScreen ? 13 : 15),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: priceWidth,
                    child: Text(
                      '\$${producto['precio'].toStringAsFixed(2)}',
                      style: TextStyle(fontSize: isSmallScreen ? 13 : 15),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 48,
                    child: PopupMenuButton<int>(
                      icon: Icon(
                        Icons.more_vert,
                        color: Colors.black,
                        size: isSmallScreen ? 20 : 24,
                      ),
                      itemBuilder: (context) =>
                      [
                        PopupMenuItem(
                          value: 1,
                          child: ListTile(
                            leading: Icon(Icons.edit, color: Colors.blue),
                            title: Text('Editar'),
                            contentPadding: EdgeInsets.zero,
                            onTap: () {
                              Navigator.pop(context);
                              _mostrarFormularioEditarProducto(producto);
                            },
                          ),
                        ),
                        PopupMenuItem(
                          value: 2,
                          child: ListTile(
                            leading: Icon(
                                Icons.attach_money, color: Colors.green),
                            title: Text('Reabastecer'),
                            contentPadding: EdgeInsets.zero,
                            onTap: () {
                              Navigator.pop(context);
                              _mostrarFormularioReabastecimiento(producto);
                            },
                          ),
                        ),
                        PopupMenuItem(
                          value: 3,
                          child: ListTile(
                            leading: Icon(
                                Icons.delete_outline, color: Colors.red),
                            title: Text('Eliminar'),
                            contentPadding: EdgeInsets.zero,
                            onTap: () {
                              Navigator.pop(context);
                              _mostrarDialogoEliminar(producto);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery
        .of(context)
        .size
        .width;
    final isSmallScreen = screenWidth < 600;
    final groupedProducts = _groupProductsByCategory();
    final sortedCategories = groupedProducts.keys.toList()
      ..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadCategorias();
              _loadProductos();
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: EdgeInsets.all(isSmallScreen ? 8.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            if (isSmallScreen) ...[
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar producto',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedFilter,
                          items: _filterOptions.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedFilter = newValue!;
                              _filterProducts();
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _mostrarFormularioAgregarProducto,
                    icon: Icon(Icons.add, size: isSmallScreen ? 20 : 24),
                    label: const Text('Añadir'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 12 : 16,
                        vertical: isSmallScreen ? 8 : 12,
                      ),
                    ),
                  ),
                ],
              ),
            ] else
              ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar producto',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedFilter,
                          items: _filterOptions.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedFilter = newValue!;
                              _filterProducts();
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _mostrarFormularioAgregarProducto,
                      icon: const Icon(Icons.add),
                      label: const Text('Añadir producto'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: sortedCategories.length,
                itemBuilder: (context, index) {
                  String category = sortedCategories[index];
                  List<Map<String,
                      dynamic>> products = groupedProducts[category]!;

                  return Card(
                    margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 18 : 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _buildProductTable(products, isSmallScreen),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoEliminar(Map<String, dynamic> producto) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar eliminación'),
          content:
          const Text('¿Estás seguro de que deseas eliminar este producto?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _eliminarProducto(producto);
              },
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarFormularioAgregarProducto() {
    final formKey = GlobalKey<FormState>();
    String nombre = '';
    String categoria = _selectedFilter == 'Todos' ? '' : _selectedFilter;
    String precio = '';
    String stock = '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Añadir Producto'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Nombre del producto',
                      border: OutlineInputBorder(),
                    ),
                    onSaved: (value) => nombre = value ?? '',
                    validator: (value) =>
                    value?.isEmpty ?? true
                        ? 'Este campo es requerido'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  // También modifica el DropdownButtonFormField en el formulario de edición
                  DropdownButtonFormField<String>(
                    value: categoria.isNotEmpty ? categoria : null,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      border: OutlineInputBorder(),
                    ),
                    items: _filterOptions
                        .where((option) => option != 'Todos')
                        .map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (value) => categoria = value ?? '',
                    validator: (value) =>
                    value == null || value.isEmpty
                        ? 'Este campo es requerido'
                        : null,
                    hint: const Text('Seleccionar categoría'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Precio',
                      border: OutlineInputBorder(),
                    ),
                    onSaved: (value) => precio = value ?? '',
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Este campo es requerido';
                      }
                      if (double.tryParse(value!) == null) {
                        return 'Ingrese un número válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Stock',
                      border: OutlineInputBorder(),
                    ),
                    onSaved: (value) => stock = value ?? '',
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Este campo es requerido';
                      }
                      if (int.tryParse(value!) == null) {
                        return 'Ingrese un número válido';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  formKey.currentState?.save();
                  _agregarProducto(nombre, categoria, precio, stock);
                  Navigator.pop(context);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarFormularioEditarProducto(Map<String, dynamic> producto) {
    final formKey = GlobalKey<FormState>();
    String nombre = producto['producto'];
    String categoria = producto['categoria'];
    String precio = producto['precio'].toString();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar Producto'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: nombre,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del producto',
                      border: OutlineInputBorder(),
                    ),
                    onSaved: (value) => nombre = value ?? '',
                    validator: (value) =>
                    value?.isEmpty ?? true
                        ? 'Este campo es requerido'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: categoria,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      border: OutlineInputBorder(),
                    ),
                    items: _filterOptions
                        .where((option) => option != 'Todos')
                        .map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (value) => categoria = value ?? '',
                    validator: (value) =>
                    value == null || value.isEmpty
                        ? 'Este campo es requerido'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: precio,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Precio',
                      border: OutlineInputBorder(),
                    ),
                    onSaved: (value) => precio = value ?? '',
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Este campo es requerido';
                      }
                      if (double.tryParse(value!) == null) {
                        return 'Ingrese un número válido';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  formKey.currentState?.save();
                  _actualizarProducto(
                      producto, nombre, categoria, precio,
                      producto['stock'].toString());
                  Navigator.pop(context);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarFormularioReabastecimiento(Map<String, dynamic> producto) {
    final TextEditingController cantidadController = TextEditingController();
    double precioPorUnidad = producto['precioCompra'];
    double precioTotal = 0.0;
    int stockActual = producto['stock'];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text('Reabastecer Producto'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Producto: ${producto['producto']}'),
                    SizedBox(height: 10),
                    Text('Precio por Unidad: \$${precioPorUnidad.toStringAsFixed(2)}'),
                    SizedBox(height: 10),
                    Text('Stock Actual: $stockActual'),
                    SizedBox(height: 10),
                    TextField(
                      controller: cantidadController,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        labelText: 'Cantidad',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        final cantidad = int.tryParse(value) ?? 0;
                        setDialogState(() {
                          precioTotal = cantidad * precioPorUnidad;
                        });
                      },
                    ),
                    SizedBox(height: 10),
                    Text('Precio Total: \$${precioTotal.toStringAsFixed(2)}'),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final cantidad = int.tryParse(cantidadController.text) ?? 0;
                    if (cantidad <= 0) {
                      _showErrorDialog('Por favor ingresa una cantidad válida.');
                      return;
                    }

                    precioTotal = cantidad * precioPorUnidad;

                    if (precioTotal > availableMoney) {
                      _showErrorDialog('Saldo insuficiente para realizar esta compra.');
                      return;
                    }

                    try {
                      // Insertar transacción de egreso
                      final transaccionResponse = await http.post(
                        Uri.parse('$baseUrl/transaccionesinsert'),
                        headers: {'Content-Type': 'application/json'},
                        body: json.encode({
                          'descripcion': 'Reabastecimiento de ${producto['producto']}',
                          'monto': precioTotal,
                          'tipo': 'egreso',
                          'fecha': DateTime.now().toIso8601String(),
                        }),
                      );

                      if (transaccionResponse.statusCode == 201) {
                        // Actualizar producto con nuevo stock
                        int nuevoStock = stockActual + cantidad;
                        await _actualizarProducto(
                          producto,
                          producto['producto'],
                          producto['categoria'],
                          producto['precio'].toString(),
                          nuevoStock.toString(),
                        );

                        // Refrescar saldo
                        await _fetchSaldo();

                        Navigator.of(context).pop();
                      } else {
                        _showErrorDialog('Error al registrar la transacción');
                      }
                    } catch (e) {
                      _showErrorDialog('Error de conexión: ${e.toString()}');
                    }
                  },
                  child: Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }





  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}