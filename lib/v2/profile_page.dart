import 'package:flutter/material.dart';
import 'package:liveness_app/home_page.dart';
import 'package:liveness_app/models/user_profile.dart';

class ProfilePage extends StatefulWidget {
  final UserProfile user;

  const ProfilePage({super.key, required this.user});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // --- State for Edit Mode ---
  bool _isEditing = false;
  bool _isLoading = false;

  // --- Form Controllers ---
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _contactController;
  String? _selectedGender;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  /// Helper to set controllers from widget.user
  void _initializeControllers() {
    _nameController = TextEditingController(text: widget.user.name);
    _emailController = TextEditingController(text: widget.user.email);
    _contactController = TextEditingController(text: widget.user.contactNumber);
    _selectedGender = widget.user.gender;
  }

  @override
  void dispose() {
    // Dispose controllers
    _nameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  /// Toggles the UI between View and Edit modes
  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;

      // If we are cancelling an edit, reset controllers to original values
      if (!_isEditing) {
        _initializeControllers();
      }
    });
  }

  /// Saves the updated user data to Hive
  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Update the user object's fields
        widget.user.name = _nameController.text;
        widget.user.email = _emailController.text;
        widget.user.contactNumber = _contactController.text;
        widget.user.gender = _selectedGender!;

        // Because UserProfile extends HiveObject, we can just call .save()
        await widget.user.save();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile Updated Successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Update Failed: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } finally {
        // Toggle back to view mode and stop loading
        setState(() {
          _isLoading = false;
          _isEditing = false;
        });
      }
    }
  }

  /// Navigates back to the Home Page
  void _navigateHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomePage()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Profile' : 'Profile Verified'),
        // Show "Cancel" or "Done" button
        leading: IconButton(
          icon: Icon(_isEditing ? Icons.close : Icons.chevron_left_outlined),
          onPressed: _isEditing ? _toggleEdit : _navigateHome,
        ),
        // Show "Save" or "Edit" button
        actions: [
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                )
              : IconButton(
                  icon: Icon(_isEditing ? Icons.save : Icons.edit),
                  onPressed: _isEditing ? _saveChanges : _toggleEdit,
                ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: MemoryImage(widget.user.profileImage),
                  backgroundColor: Colors.grey.shade200,
                ),
                const SizedBox(height: 20),
                // --- Conditionally render View or Edit ---
                _isEditing ? _buildEditForm() : _buildViewInfo(),
                const SizedBox(height: 40),
                if (!_isEditing) // Show "Done" button only in view mode
                  ElevatedButton(
                    onPressed: _navigateHome,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text('Done'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the read-only view of user data
  Widget _buildViewInfo() {
    return Column(
      children: [
        Text(
          'Welcome Back, ${widget.user.name}!',
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          'Your identity has been successfully verified.',
          style: TextStyle(fontSize: 16, color: Colors.black54),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        Card(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileInfoRow(
                  icon: Icons.email,
                  label: 'Email',
                  value: widget.user.email,
                ),
                const Divider(height: 24),
                _buildProfileInfoRow(
                  icon: Icons.phone,
                  label: 'Contact',
                  value: widget.user.contactNumber,
                ),
                const Divider(height: 24),
                _buildProfileInfoRow(
                  icon: Icons.wc,
                  label: 'Gender',
                  value: widget.user.gender,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the editable form fields
  Widget _buildEditForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          const SizedBox(height: 16),
          const Text(
            'Update your profile details below.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 32),
          _buildTextFormField(
            controller: _nameController,
            labelText: 'Full Name',
            icon: Icons.person,
            validator: (value) =>
                value!.isEmpty ? 'Please enter your name' : null,
          ),
          const SizedBox(height: 20),
          _buildTextFormField(
            controller: _emailController,
            labelText: 'Email Address',
            icon: Icons.email,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value!.isEmpty) {
                return 'Please enter your email';
              }
              if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildTextFormField(
            controller: _contactController,
            labelText: 'Contact Number',
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
            validator: (value) =>
                value!.isEmpty ? 'Please enter your contact number' : null,
          ),
          const SizedBox(height: 20),
          _buildGenderDropdown(),
        ],
      ),
    );
  }

  // --- Form Field Helper Widgets ---

  Widget _buildProfileInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.pinkAccent, size: 28),
        const SizedBox(width: 16),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontSize: 18, color: Colors.black87),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      keyboardType: keyboardType,
      validator: validator,
    );
  }

  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Gender',
        prefixIcon: const Icon(Icons.wc),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      initialValue: _selectedGender,
      hint: const Text('Select Gender'),
      items: ['Male', 'Female', 'Other', 'Prefer not to say']
          .map((gender) => DropdownMenuItem(value: gender, child: Text(gender)))
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedGender = value;
        });
      },
      validator: (value) => value == null ? 'Please select a gender' : null,
    );
  }
}
