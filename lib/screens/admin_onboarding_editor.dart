import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';

class AdminOnboardingEditor extends StatefulWidget {
  const AdminOnboardingEditor({super.key});

  @override
  State<AdminOnboardingEditor> createState() => _AdminOnboardingEditorState();
}

class _AdminOnboardingEditorState extends State<AdminOnboardingEditor> {
  List<Map<String, dynamic>> _slides = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSlides();
  }

  Future<void> _fetchSlides() async {
    try {
      final response = await Supabase.instance.client
          .from('onboarding_slides')
          .select()
          .order('slide_order');

      if (mounted) {
        setState(() {
          _slides = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Fetch slides error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load slides: $e')),
        );
      }
    }
  }

  void _showSlideDialog({Map<String, dynamic>? existing}) {
    final orderCtrl = TextEditingController(
      text: existing?['slide_order']?.toString() ?? '',
    );
    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    final descCtrl =
        TextEditingController(text: existing?['description'] ?? '');
    bool active = existing?['is_active'] ?? true;

    File? _selectedImageFile; // for mobile
    Uint8List? _selectedImageBytes; // for web preview
    String? _currentImageUrl = existing?['image_url'];
    bool _isUploading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add New Slide' : 'Edit Slide'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: orderCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Slide Order',
                    helperText: 'Unique number (e.g. 1, 2, 3...)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                // Image Picker + Preview
                const Text(
                  'Slide Image',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked =
                        await picker.pickImage(source: ImageSource.gallery);
                    if (picked != null && mounted) {
                      if (kIsWeb) {
                        // Web: read bytes for preview
                        final bytes = await picked.readAsBytes();
                        setDialogState(() {
                          _selectedImageBytes = bytes;
                          _selectedImageFile = null;
                        });
                      } else {
                        // Mobile: use File
                        setDialogState(() {
                          _selectedImageFile = File(picked.path);
                          _selectedImageBytes = null;
                        });
                      }
                    }
                  },
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade100,
                    ),
                    child: _isUploading
                        ? const Center(child: CircularProgressIndicator())
                        : _selectedImageFile != null && !kIsWeb
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  _selectedImageFile!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : _selectedImageBytes != null && kIsWeb
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.memory(
                                      _selectedImageBytes!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : _currentImageUrl != null &&
                                        _currentImageUrl!.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          _currentImageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Center(
                                            child: Icon(Icons.broken_image,
                                                size: 50, color: Colors.grey),
                                          ),
                                        ),
                                      )
                                    : const Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                                Icons
                                                    .add_photo_alternate_outlined,
                                                size: 50,
                                                color: Colors.grey),
                                            SizedBox(height: 8),
                                            Text(
                                              'Tap to choose image from gallery',
                                              style:
                                                  TextStyle(color: Colors.grey),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: titleCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Title (optional)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Description (optional)'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Active (show in onboarding)'),
                  value: active,
                  onChanged: (val) => setDialogState(() => active = val),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565FF),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final orderText = orderCtrl.text.trim();
                final order = int.tryParse(orderText);

                if (order == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Please enter a valid slide order (number)')),
                  );
                  return;
                }

                String? finalImageUrl = _currentImageUrl;

                if (_selectedImageFile != null || _selectedImageBytes != null) {
                  setDialogState(() => _isUploading = true);

                  try {
                    Uint8List? bytes;
                    String fileExt;

                    if (kIsWeb) {
                      bytes = _selectedImageBytes;
                      fileExt = '.jpg'; // or detect from mime if you have it
                    } else {
                      bytes = await _selectedImageFile!.readAsBytes();
                      fileExt = path.extension(_selectedImageFile!.path);
                    }

                    final fileName =
                        '${DateTime.now().millisecondsSinceEpoch}$fileExt';

                    await Supabase.instance.client.storage
                        .from('onboarding-images')
                        .uploadBinary(fileName, bytes!);

                    finalImageUrl = Supabase.instance.client.storage
                        .from('onboarding-images')
                        .getPublicUrl(fileName);
                  } catch (e) {
                    setDialogState(() => _isUploading = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Image upload failed: $e')),
                    );
                    return;
                  }

                  setDialogState(() => _isUploading = false);
                }

                if (finalImageUrl == null || finalImageUrl.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select an image')),
                  );
                  return;
                }

                final data = {
                  'slide_order': order,
                  'image_url': finalImageUrl,
                  'title': titleCtrl.text.trim().isEmpty
                      ? null
                      : titleCtrl.text.trim(),
                  'description': descCtrl.text.trim().isEmpty
                      ? null
                      : descCtrl.text.trim(),
                  'is_active': active,
                };

                try {
                  if (existing == null) {
                    await Supabase.instance.client
                        .from('onboarding_slides')
                        .insert(data);
                  } else {
                    await Supabase.instance.client
                        .from('onboarding_slides')
                        .update(data)
                        .eq('id', existing['id']);
                  }

                  _fetchSlides();
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(existing == null
                          ? 'Slide added successfully!'
                          : 'Slide updated!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving slide: $e')),
                  );
                }
              },
              child: Text(existing == null ? 'Add Slide' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Onboarding Slides'),
        backgroundColor: const Color(0xFF1565FF),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _slides.isEmpty
              ? const Center(
                  child: Text(
                    'No slides yet.\nTap + to add your first onboarding slide!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _slides.length,
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    final imageUrl =
                        (slide['image_url']?.toString() ?? '').trim();

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: imageUrl.isNotEmpty
                              ? Image.network(
                                  imageUrl,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      width: 60,
                                      height: 60,
                                      color: Colors.grey[200],
                                      child: const Center(
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2)),
                                    );
                                  },
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.broken_image,
                                        color: Colors.grey),
                                  ),
                                )
                              : Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.image_not_supported,
                                      color: Colors.grey),
                                ),
                        ),
                        title: Text(
                          'Slide ${slide['slide_order']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              imageUrl.isNotEmpty ? imageUrl : 'No image',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (slide['title'] != null)
                              Text(
                                'Title: ${slide['title']}',
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              slide['is_active']
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: slide['is_active']
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () =>
                                  _showSlideDialog(existing: slide),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Slide?'),
                                    content:
                                        const Text('This cannot be undone.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Delete',
                                            style:
                                                TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  try {
                                    await Supabase.instance.client
                                        .from('onboarding_slides')
                                        .delete()
                                        .eq('id', slide['id']);
                                    _fetchSlides();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Slide deleted')),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text('Error deleting: $e')),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1565FF),
        icon: const Icon(Icons.add),
        label: const Text('Add Slide'),
        onPressed: () => _showSlideDialog(),
      ),
    );
  }
}
