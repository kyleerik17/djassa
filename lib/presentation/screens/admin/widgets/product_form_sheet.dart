import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sizer/sizer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart'
    as path; // Ajoutez cette dépendance dans pubspec.yaml si besoin, ou utilisez string manipulation

// Importez votre thème ici
// import '../../../../core/theme/djassa_theme.dart';

// --- Modèles Locaux pour l'UI ---
class VehicleMake {
  final String id;
  final String name;
  VehicleMake({required this.id, required this.name});
}

class VehicleModel {
  final String id;
  final String name;
  VehicleModel({required this.id, required this.name});
}

class VehicleGeneration {
  final String id;
  final String name;
  final int yearStart;
  VehicleGeneration(
      {required this.id, required this.name, required this.yearStart});
}

class AdminCategory {
  final String id;
  final String name;
  AdminCategory({required this.id, required this.name});
}

// Provider Supabase
final supabaseClientProvider =
    Provider<SupabaseClient>((ref) => Supabase.instance.client);

class AdminProductFormSheet extends ConsumerStatefulWidget {
  const AdminProductFormSheet({super.key, this.product});
  final Map<String, dynamic>? product;

  @override
  ConsumerState<AdminProductFormSheet> createState() =>
      _AdminProductFormSheetState();
}

class _AdminProductFormSheetState extends ConsumerState<AdminProductFormSheet> {
  // Controllers
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _badgeController = TextEditingController(text: 'Top');

  // État UI
  bool _isSubmitting = false;
  bool _isLoadingData = true;
  bool _isUploadingImage = false; // Nouvel état pour l'upload
  File? _imageFile;
  String? _existingImageUrl;
  bool _isAutoPart = false;

  // Données Dynamiques
  List<AdminCategory> _categories = [];
  List<VehicleMake> _makes = [];
  List<VehicleModel> _models = [];
  List<VehicleGeneration> _generations = [];

  // Sélections
  String? _selectedCategoryId;
  String? _selectedMakeId;
  String? _selectedModelId;
  String? _selectedGenId;

  // Couleurs
  Color get accentOrange => const Color(0xFFFF6B00);
  Color get primaryBlack => const Color(0xFF121212);

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final supabase = ref.read(supabaseClientProvider);
    try {
      final results = await Future.wait([
        supabase.from('categories').select('id, name').eq('is_active', true),
        supabase.from('vehicle_makes').select('id, name').eq('is_active', true),
      ]);

      _categories = (results[0] as List)
          .map((c) => AdminCategory(id: c['id'], name: c['name']))
          .toList();
      _makes = (results[1] as List)
          .map((m) => VehicleMake(id: m['id'], name: m['name']))
          .toList();

      if (widget.product != null) {
        final p = widget.product!;
        _nameController.text = p['name'] ?? '';
        _descController.text = p['description'] ?? '';
        _priceController.text = '${p['price']}';
        _stockController.text = '${p['stock']}';
        _badgeController.text = p['badge'] ?? 'Top';
        _selectedCategoryId = p['category_id'];
        _existingImageUrl = p['image_url'];

        final compatRes = await supabase
            .from('product_compatibility')
            .select('make_id, model_id, generation_id')
            .eq('product_id', p['id'])
            .limit(1);

        if (compatRes.isNotEmpty) {
          setState(() {
            _isAutoPart = true;
            _selectedMakeId = compatRes[0]['make_id'];
            _selectedModelId = compatRes[0]['model_id'];
            _selectedGenId = compatRes[0]['generation_id'];
          });
          if (_selectedMakeId != null) await _onMakeChanged(_selectedMakeId);
          if (_selectedModelId != null) await _onModelChanged(_selectedModelId);
        }
      }
    } catch (e) {
      debugPrint("Erreur chargement données: $e");
      _showError("Impossible de charger les données initiales: $e");
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _onMakeChanged(String? makeId) async {
    final supabase = ref.read(supabaseClientProvider);
    setState(() {
      _selectedMakeId = makeId;
      _selectedModelId = null;
      _selectedGenId = null;
      _models = [];
      _generations = [];
    });
    if (makeId != null) {
      final res = await supabase
          .from('vehicle_models')
          .select('id, name')
          .eq('make_id', makeId);
      setState(() => _models = (res as List)
          .map((m) => VehicleModel(id: m['id'], name: m['name']))
          .toList());
    }
  }

  Future<void> _onModelChanged(String? modelId) async {
    final supabase = ref.read(supabaseClientProvider);
    setState(() {
      _selectedModelId = modelId;
      _selectedGenId = null;
      _generations = [];
    });
    if (modelId != null) {
      final res = await supabase
          .from('vehicle_generations')
          .select('id, name, year_start')
          .eq('model_id', modelId)
          .order('year_start', ascending: false);
      setState(() => _generations = (res as List)
          .map((g) => VehicleGeneration(
              id: g['id'], name: g['name'], yearStart: g['year_start']))
          .toList());
    }
  }

  // ✅ CORRECTION IMAGE PICKER
  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      // On demande une image de qualité maximale mais on laisse le système la compresser si possible
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth:
            1800, // Limite la largeur pour éviter les fichiers trop lourds
        maxHeight: 1800,
        imageQuality: 85, // Compression JPEG à 85%
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _existingImageUrl =
              null; // On efface l'ancienne URL car une nouvelle image arrive
        });
      }
    } catch (e) {
      _showError("Erreur lors de la sélection de l'image: $e");
    }
  }

  // ✅ CORRECTION UPLOAD SUPABASE
  Future<String?> _uploadImageToSupabase() async {
    if (_imageFile == null) return _existingImageUrl;

    setState(() => _isUploadingImage = true);
    final supabase = ref.read(supabaseClientProvider);

    try {
      // Génération d'un nom de fichier unique pour éviter les conflits
      final ext = path.extension(_imageFile!
          .path); // Nécessite import 'package:path/path.dart' as path;
      // Si vous ne voulez pas ajouter le package path, utilisez:
      // final ext = _imageFile!.path.split('.').last;

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch}$ext';

      debugPrint("Début upload vers: products/$fileName");

      // Upload du fichier
      final storageResponse = await supabase.storage
          .from(
              'products') // Assurez-vous que ce bucket existe et est PUBLIC ou a les bonnes policies
          .upload(fileName, _imageFile!);

      if (storageResponse.isEmpty) {
        throw Exception("Échec de l'upload: Réponse vide");
      }

      // Récupération de l'URL publique
      final imageUrl = supabase.storage.from('products').getPublicUrl(fileName);
      debugPrint("Upload réussi: $imageUrl");

      return imageUrl;
    } on StorageException catch (e) {
      debugPrint("Erreur Storage Supabase: ${e.message}");
      _showError(
          "Erreur d'upload: ${e.message}. Vérifiez que le bucket 'products' existe et est public.");
      return null;
    } catch (e) {
      debugPrint("Erreur générale upload: $e");
      _showError("Une erreur inattendue est survenue lors de l'upload.");
      return null;
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  final _formKey = GlobalKey<FormState>();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      _showError("Veuillez sélectionner une catégorie");
      return;
    }
    if (_isAutoPart &&
        (_selectedGenId == null ||
            _selectedModelId == null ||
            _selectedMakeId == null)) {
      _showError("Veuillez compléter les détails techniques");
      return;
    }

    setState(() => _isSubmitting = true);
    final supabase = ref.read(supabaseClientProvider);

    try {
      // 1. Upload Image d'abord
      final imageUrl = await _uploadImageToSupabase();

      // Si l'upload a échoué et qu'on n'avait pas d'image existante, on arrête
      if (imageUrl == null && _existingImageUrl == null && _imageFile != null) {
        _showError("L'image n'a pas pu être téléchargée. Veuillez réessayer.");
        setState(() => _isSubmitting = false);
        return;
      }

      final productData = {
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'price': int.parse(_priceController.text),
        'stock': int.parse(_stockController.text),
        'badge': _badgeController.text.trim(),
        'category_id': _selectedCategoryId,
        'image_url': imageUrl ??
            _existingImageUrl, // Garde l'ancienne si pas de nouvelle
        'updated_at': DateTime.now().toIso8601String(),
        'slug': _nameController.text.trim().toLowerCase().replaceAll(' ', '-'),
      };

      String productId;
      if (widget.product != null) {
        productId = widget.product!['id'];
        await supabase.from('products').update(productData).eq('id', productId);
      } else {
        productData['created_at'] = DateTime.now().toIso8601String();
        final res = await supabase
            .from('products')
            .insert(productData)
            .select('id')
            .single();
        productId = res['id'];
      }

      // Gestion des détails techniques optionnels.
      if (_isAutoPart && _selectedGenId != null) {
        if (widget.product != null)
          await supabase
              .from('product_compatibility')
              .delete()
              .eq('product_id', productId);
        await supabase.from('product_compatibility').insert({
          'product_id': productId,
          'make_id': _selectedMakeId,
          'model_id': _selectedModelId,
          'generation_id': _selectedGenId,
          'year_start':
              _generations.firstWhere((g) => g.id == _selectedGenId).yearStart,
        });
      } else if (widget.product != null) {
        await supabase
            .from('product_compatibility')
            .delete()
            .eq('product_id', productId);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError("Erreur lors de la sauvegarde: $e");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Attention"),
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
              child: const Text("OK"), onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    );
  }

  // --- WIDGETS DE DESIGN RESPONSIVE ---

  Widget _buildCard(String title, IconData icon, List<Widget> children,
      {Color? headerColor}) {
    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3.w),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(2.w),
                  decoration: BoxDecoration(
                    color: (headerColor ?? accentOrange).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(2.w),
                  ),
                  child:
                      Icon(icon, color: headerColor ?? accentOrange, size: 5.w),
                ),
                SizedBox(width: 3.w),
                Text(title,
                    style: TextStyle(
                        fontSize: 4.5.w,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          Padding(
              padding: EdgeInsets.all(5.w), child: Column(children: children)),
        ],
      ),
    );
  }

  InputDecoration _inputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 3.5.w, color: Colors.grey[600]),
      prefixIcon: Icon(icon, size: 5.w, color: Colors.grey[500]),
      filled: true,
      fillColor: const Color(0xFFF8F9FA),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3.w),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3.w),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3.w),
          borderSide: BorderSide(color: accentOrange, width: 2)),
      contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) return const Center(child: CircularProgressIndicator());

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(5.w)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(6.w, 6.h, 6.w, 3.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [accentOrange, accentOrange.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.vertical(top: Radius.circular(5.w)),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              widget.product != null
                                  ? "MODIFICATION"
                                  : "CRÉATION",
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 3.5.w,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1)),
                          SizedBox(height: 0.5.h),
                          Text(
                              widget.product != null
                                  ? "Modifier l'article"
                                  : "Nouvel article",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 6.w,
                                  fontWeight: FontWeight.bold)),
                        ]),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.all(2.w),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle),
                        child: Icon(CupertinoIcons.xmark,
                            color: Colors.white, size: 5.w),
                      ),
                    )
                  ],
                ),
              ),
            ),

            // Contenu Scrollable
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: controller,
                  padding: EdgeInsets.all(5.w),
                  children: [
                    // IMAGE UPLOAD CIRCULAIRE AMÉLIORÉ
                    Center(
                      child: GestureDetector(
                        onTap: _isUploadingImage ? null : _pickImage,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              height: 28.w,
                              width: 28.w,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 4),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 20,
                                      offset: Offset(0, 8))
                                ],
                                image: _imageFile != null
                                    ? DecorationImage(
                                        image: FileImage(_imageFile!),
                                        fit: BoxFit.cover)
                                    : (_existingImageUrl != null
                                        ? DecorationImage(
                                            image: NetworkImage(
                                                _existingImageUrl!),
                                            fit: BoxFit.cover)
                                        : null),
                              ),
                              child: (_imageFile == null &&
                                      _existingImageUrl == null)
                                  ? Icon(CupertinoIcons.camera_fill,
                                      size: 8.w, color: Colors.grey[400])
                                  : null,
                            ),

                            // Overlay de chargement
                            if (_isUploadingImage)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 3),
                                  ),
                                ),
                              ),

                            // Badge Add
                            if (!_isUploadingImage)
                              Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: EdgeInsets.all(2.w),
                                    decoration: BoxDecoration(
                                        color: accentOrange,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 2)),
                                    child: Icon(CupertinoIcons.add,
                                        color: Colors.white, size: 4.w),
                                  ))
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 4.h),

                    // CARTES D'INFORMATIONS
                    _buildCard("Général", CupertinoIcons.bag, [
                      TextFormField(
                          controller: _nameController,
                          decoration:
                              _inputStyle("Nom du produit", CupertinoIcons.tag),
                          validator: (v) => v!.isEmpty ? "Requis" : null),
                      SizedBox(height: 2.h),
                      DropdownButtonFormField<String>(
                        value: _selectedCategoryId,
                        items: _categories
                            .map((c) => DropdownMenuItem(
                                value: c.id, child: Text(c.name)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedCategoryId = v),
                        decoration:
                            _inputStyle("Catégorie", CupertinoIcons.grid)
                                .copyWith(
                                    filled: true,
                                    fillColor: const Color(0xFFF8F9FA)),
                        validator: (v) => v == null ? "Requis" : null,
                      ),
                      SizedBox(height: 2.h),
                      TextFormField(
                          controller: _descController,
                          maxLines: 3,
                          decoration: _inputStyle("Description détaillée",
                                  CupertinoIcons.doc_text)
                              .copyWith(alignLabelWithHint: true)),
                    ]),

                    _buildCard(
                        "Vente",
                        CupertinoIcons.creditcard,
                        [
                          Row(children: [
                            Expanded(
                                child: TextFormField(
                                    controller: _priceController,
                                    keyboardType: TextInputType.number,
                                    decoration: _inputStyle("Prix (FCFA)",
                                        CupertinoIcons.money_dollar))),
                            SizedBox(width: 3.w),
                            Expanded(
                                child: TextFormField(
                                    controller: _stockController,
                                    keyboardType: TextInputType.number,
                                    decoration: _inputStyle(
                                        "Stock", CupertinoIcons.archivebox))),
                          ]),
                        ],
                        headerColor: Colors.blue),

                    // DÉTAILS TECHNIQUES OPTIONNELS
                    Container(
                      margin: EdgeInsets.only(bottom: 2.h),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(3.w),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 15)
                          ]),
                      child: ExpansionTile(
                        initiallyExpanded: _isAutoPart,
                        onExpansionChanged: (val) =>
                            setState(() => _isAutoPart = val),
                        tilePadding: EdgeInsets.symmetric(
                            horizontal: 5.w, vertical: 1.h),
                        leading: Container(
                          padding: EdgeInsets.all(2.w),
                          decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(2.w)),
                          child: Icon(CupertinoIcons.cube_box_fill,
                              color: Colors.purple, size: 5.w),
                        ),
                        title: Text("Détails techniques",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 4.5.w)),
                        subtitle: Text(
                            _isAutoPart
                                ? "Masquer les détails"
                                : "Ajouter type, modèle ou variante",
                            style: TextStyle(fontSize: 3.2.w)),
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(5.w, 0, 5.w, 3.h),
                            child: Column(
                              children: [
                                DropdownButtonFormField<String>(
                                    value: _selectedMakeId,
                                    hint: Text("Marque / gamme",
                                        style: TextStyle(fontSize: 3.5.w)),
                                    items: _makes
                                        .map((m) => DropdownMenuItem(
                                            value: m.id, child: Text(m.name)))
                                        .toList(),
                                    onChanged: _onMakeChanged,
                                    decoration:
                                        _inputStyle("", CupertinoIcons.tag)),
                                SizedBox(height: 2.h),
                                DropdownButtonFormField<String>(
                                    value: _selectedModelId,
                                    hint: Text("Modèle / variante",
                                        style: TextStyle(fontSize: 3.5.w)),
                                    items: _models
                                        .map((m) => DropdownMenuItem(
                                            value: m.id, child: Text(m.name)))
                                        .toList(),
                                    onChanged: _selectedMakeId != null
                                        ? _onModelChanged
                                        : null,
                                    decoration: _inputStyle(
                                        "", CupertinoIcons.cube_box)),
                                SizedBox(height: 2.h),
                                DropdownButtonFormField<String>(
                                    value: _selectedGenId,
                                    hint: Text("Année / version",
                                        style: TextStyle(fontSize: 3.5.w)),
                                    items: _generations
                                        .map((g) => DropdownMenuItem(
                                            value: g.id,
                                            child: Text(
                                                "${g.name} (${g.yearStart})")))
                                        .toList(),
                                    onChanged: _selectedModelId != null
                                        ? (v) =>
                                            setState(() => _selectedGenId = v)
                                        : null,
                                    decoration: _inputStyle(
                                        "", CupertinoIcons.calendar_today)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 3.h),

                    // BOUTON FINAL
                    CupertinoButton.filled(
                      onPressed:
                          (_isSubmitting || _isUploadingImage) ? null : _submit,
                      padding: EdgeInsets.symmetric(vertical: 3.h),
                      borderRadius: BorderRadius.circular(3.w),
                      child: _isSubmitting
                          ? SizedBox(
                              width: 5.w,
                              height: 5.w,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                  Icon(CupertinoIcons.check_mark_circled,
                                      size: 5.w),
                                  SizedBox(width: 2.w),
                                  Text("Enregistrer l'article",
                                      style: TextStyle(
                                          fontSize: 4.5.w,
                                          fontWeight: FontWeight.bold))
                                ]),
                    ),
                    SizedBox(height: 5.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
