import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:animations/animations.dart'; // Para transiciones suaves

class UsuariosPage extends StatefulWidget {
  const UsuariosPage({super.key});

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _usuariosActivos = [];
  List<Map<String, dynamic>> _usuariosInactivos = [];
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarUsuarios();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  Future<void> _cargarUsuarios() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await http.get(
        Uri.parse('https://modelo-server.vercel.app/api/v1/trabajadores'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          // Filtramos por los estados como strings: 'activo' e 'inactivo'
          _usuariosActivos = data
              .where((user) => user['estado'] == 'activo')
              .map((user) => user as Map<String, dynamic>)
              .toList();
          _usuariosInactivos = data
              .where((user) => user['estado'] == 'inactivo')
              .map((user) => user as Map<String, dynamic>)
              .toList();

          // Ordenamos los usuarios por rol, poniendo a los 'propietario' primero
          _usuariosActivos.sort((a, b) => a['rol'] == 'propietario' ? -1 : 1);
          _usuariosInactivos.sort((a, b) => a['rol'] == 'propietario' ? -1 : 1);

          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Error al cargar usuarios: ${response.statusCode}';
          _isLoading = false;
        });
        print('Error al cargar usuarios: ${response.statusCode}');
        print('Respuesta: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _error = 'Error de conexión';
        _isLoading = false;
      });
      print('Error de conexión al cargar usuarios: $e');
    }
  }


  Future<void> _cambiarEstadoUsuario(dynamic id, String nuevoEstado) async {
    try {
      final response = await http.patch(
        Uri.parse('https://modelo-server.vercel.app/api/v1/trabajadores/$id/estado'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'estado': nuevoEstado}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(nuevoEstado == 'activo' ? 'Usuario activado' : 'Usuario desactivado')),
        );
        _cargarUsuarios();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cambiar estado del usuario: ${response.statusCode}')),
        );
        print('Error al cambiar estado del usuario: ${response.statusCode}');
        print('Respuesta: ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión')),
      );
      print('Error de conexión al cambiar estado del usuario: $e');
    }
  }

  Future<void> _eliminarUsuario(dynamic id) async {
    try {
      final response = await http.delete(
        Uri.parse('https://modelo-server.vercel.app/api/v1/trabajadores/$id/eliminar'), // Actualiza la URL aquí
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Usuario eliminado permanentemente')),
        );
        _cargarUsuarios();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar usuario: ${response.statusCode}')),
        );
        print('Error al eliminar usuario: ${response.statusCode}');
        print('Respuesta: ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión')),
      );
      print('Error de conexión al eliminar usuario: $e');
    }
  }

  void _mostrarDialogoCambiarEstado(Map<String, dynamic> usuario, String nuevoEstado) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(nuevoEstado == 'activo' ? 'Activar Usuario' : 'Desactivar Usuario'),
        content: Text(
            '¿Estás seguro de que deseas ${nuevoEstado == 'activo' ? 'activar' : 'desactivar'} a ${usuario['nombre']}?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Verificar que el campo de identificación es correcto
              var id = usuario['id']; // Asegúrate de que 'id' es el campo correcto
              if (id == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ID del usuario no encontrado')),
                );
                print('Error: ID del usuario no encontrado en: $usuario');
                return;
              }
              _cambiarEstadoUsuario(id, nuevoEstado);
            },
            child: Text(
              nuevoEstado == 'activo' ? 'Activar' : 'Desactivar',
              style: TextStyle(color: nuevoEstado == 'activo' ? Colors.green : Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoEliminarPermanente(Map<String, dynamic> usuario) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar Permanentemente'),
        content: Text(
            '¿Estás seguro de que deseas eliminar permanentemente a ${usuario['nombre']}?\n\n'
                'Esta acción no se puede deshacer.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              var id = usuario['id']; // Asegúrate de que 'id' es el campo correcto
              if (id == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ID del usuario no encontrado')),
                );
                print('Error: ID del usuario no encontrado en: $usuario');
                return;
              }
              _eliminarUsuario(id);
            },
            child: Text(
              'Eliminar Permanentemente',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarDialogoAgregarUsuario() async {
    final formKey = GlobalKey<FormState>();
    final nombreController = TextEditingController();
    final correoController = TextEditingController();
    final passwordController = TextEditingController();
    String rolSeleccionado = 'empleado';
    String estadoSeleccionado = 'activo';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Agregar Nuevo Usuario'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nombreController,
                  decoration: InputDecoration(labelText: 'Nombre'),
                  validator: (value) =>
                  value?.isEmpty ?? true ? 'Campo requerido' : null,
                ),
                TextFormField(
                  controller: correoController,
                  decoration: InputDecoration(labelText: 'Correo electrónico'),
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Campo requerido';
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value!))
                      return 'Correo inválido';
                    return null;
                  },
                ),
                TextFormField(
                  controller: passwordController,
                  decoration: InputDecoration(labelText: 'Contraseña'),
                  obscureText: true,
                  validator: (value) =>
                  value?.isEmpty ?? true ? 'Campo requerido' : null,
                ),
                DropdownButtonFormField<String>(
                  value: rolSeleccionado,
                  decoration: InputDecoration(labelText: 'Rol'),
                  items: ['propietario', 'empleado'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (value) {
                    rolSeleccionado = value!;
                  },
                ),
                // El campo de estado se ha eliminado, ya que se toma como "activo"
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  final response = await http.post(
                    Uri.parse('https://modelo-server.vercel.app/api/v1/registrar'), // Cambia aquí la URL
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      'nombre': nombreController.text,
                      'correo': correoController.text,
                      'password': passwordController.text,
                      'rol': rolSeleccionado,
                      // No necesitas 'estado', ya que el backend lo establece automáticamente
                    }),
                  );

                  if (response.statusCode == 201) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Usuario agregado con éxito')),
                    );
                    _cargarUsuarios();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al agregar usuario: ${response.statusCode}')),
                    );
                    print('Error al agregar usuario: ${response.statusCode}');
                    print('Respuesta: ${response.body}');
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error de conexión')),
                  );
                  print('Error de conexión al agregar usuario: $e');
                } finally {
                  // Cierra el diálogo después de manejar la respuesta
                  Navigator.pop(context);
                }
              }
            },
            child: Text('Agregar'),
          ),
        ],
      ),
    );

  }

  Widget _buildUsuarioCard(Map<String, dynamic> usuario, String estado, {bool esActivo = false}) {
    bool esActivoUsuario = estado == 'activo';
    return OpenContainer(
      closedElevation: 0,
      openElevation: 6,
      closedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: esActivoUsuario ? Colors.green.shade100 : Colors.grey.shade200, width: 1)
      ),
      openShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32),
      ),
      closedColor: Theme.of(context).cardColor,
      openColor: Theme.of(context).scaffoldBackgroundColor,
      closedBuilder: (context, openContainer) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ListTile(
          onTap: openContainer,
          leading: CircleAvatar(
            backgroundColor: esActivoUsuario
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.secondaryContainer,
            child: Text(
              usuario['nombre'][0].toUpperCase(),
              style: TextStyle(
                  color: esActivoUsuario
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.secondary
              ),
            ),
          ),
          title: Text(
            usuario['nombre'],
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                usuario['correo'],
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'Rol: ${usuario['rol']}',
                style: TextStyle(
                  color: usuario['rol'] == 'propietario'
                      ? Colors.blue.shade700
                      : Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  esActivoUsuario ? Icons.person_off_outlined : Icons.person_add_outlined,
                  color: esActivoUsuario ? Colors.red : Colors.green,
                ),
                onPressed: () => _mostrarDialogoCambiarEstado(usuario, esActivoUsuario ? 'inactivo' : 'activo'),
              ),
              if (!esActivo)
                IconButton(
                  icon: Icon(Icons.delete_sweep, color: Colors.red.shade700),
                  onPressed: () => _mostrarDialogoEliminarPermanente(usuario),
                ),
            ],
          ),
        ),
      ),
      openBuilder: (context, closeContainer) => _detalleUsuario(usuario),
    );
  }

  Widget _detalleUsuario(Map<String, dynamic> usuario) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalles de ${usuario['nombre']}'),
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              usuario['nombre'][0].toUpperCase(),
              style: TextStyle(
                  fontSize: 48,
                  color: Theme.of(context).colorScheme.primary
              ),
            ),
          ),
          SizedBox(height: 16),
          Center(
            child: Text(
              usuario['nombre'],
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          Center(
            child: Text(
              usuario['correo'],
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          SizedBox(height: 16),
          ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('Rol'),
            subtitle: Text(
              usuario['rol'],
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: usuario['rol'] == 'propietario' ? Colors.blue : Colors.green,
              ),
            ),
          ),
          ListTile(
            leading: Icon(usuario['estado'] == 'activo' ? Icons.check_circle : Icons.block),
            title: Text('Estado'),
            subtitle: Text(
              usuario['estado'],
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: usuario['estado'] == 'activo' ? Colors.green : Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Gestión de Usuarios',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_alt_outlined),
                  SizedBox(width: 8),
                  Text('Activos'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline),
                  SizedBox(width: 8),
                  Text('Inactivos'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_outlined),
            onPressed: _cargarUsuarios,
            tooltip: 'Recargar usuarios',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarDialogoAgregarUsuario,
        icon: Icon(Icons.add_outlined),
        label: Text('Agregar Usuario'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: _isLoading
          ? Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary
            ),
          )
      )
          : _error != null
          ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(_error!, style: Theme.of(context).textTheme.titleMedium),
            ],
          )
      )
          : TabBarView(
        controller: _tabController,
        children: [
          _usuariosActivos.isEmpty
              ? _EmptyStateWidget(
            icon: Icons.people_alt_outlined,
            mensaje: 'No hay usuarios activos',
          )
              : ListView.builder(
            padding: EdgeInsets.all(8),
            itemCount: _usuariosActivos.length,
            itemBuilder: (context, index) =>
                _buildUsuarioCard(_usuariosActivos[index], 'activo', esActivo: true),
          ),
          _usuariosInactivos.isEmpty
              ? _EmptyStateWidget(
            icon: Icons.people_outline,
            mensaje: 'No hay usuarios inactivos',
          )
              : ListView.builder(
            padding: EdgeInsets.all(8),
            itemCount: _usuariosInactivos.length,
            itemBuilder: (context, index) =>
                _buildUsuarioCard(_usuariosInactivos[index], 'inactivo', esActivo: false),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String mensaje;

  const _EmptyStateWidget({
    required this.icon,
    required this.mensaje,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
              icon,
              size: 100,
              color: Colors.grey.shade300
          ),
          SizedBox(height: 16),
          Text(
              mensaje,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey.shade600
              )
          ),
        ],
      ),
    );
  }
}