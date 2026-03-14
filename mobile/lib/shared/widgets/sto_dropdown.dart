import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StoDropdown extends StatefulWidget {
  final Function(
          String region, String district, String subDistrict, String stoName)
      onChanged;

  const StoDropdown({super.key, required this.onChanged});

  @override
  State<StoDropdown> createState() => _StoDropdownState();
}

class _StoDropdownState extends State<StoDropdown> {
  Map<String, dynamic> _stoData = {};

  String? _selectedRegion;
  String? _selectedDistrict;
  String? _selectedSubDistrict;
  String? _selectedSto;

  List<String> _regions = [];
  List<String> _districts = [];
  List<String> _subDistricts = [];
  List<String> _stos = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final String raw = await rootBundle.loadString('assets/data/sto_data.json');
    final Map<String, dynamic> data = json.decode(raw);
    setState(() {
      _stoData = data;
      _regions = data.keys.toList()..sort();
    });
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      hintText: label,
      hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
      filled: true,
      fillColor: const Color(0xFFF0F0F0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Region
        DropdownButtonFormField<String>(
          initialValue: _selectedRegion,
          style: TextStyle(
            color: _selectedRegion != null ? Colors.black87 : Colors.black38,
            fontSize: 14,
          ),
          decoration: _dropdownDecoration('Region'),
          hint: const Text('Pilih Region'),
          items: _regions
              .map((r) => DropdownMenuItem(value: r, child: Text(r)))
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedRegion = value;
              _selectedDistrict = null;
              _selectedSubDistrict = null;
              _selectedSto = null;
              _districts = (_stoData[value] as Map<String, dynamic>)
                  .keys
                  .toList()
                ..sort();
              _subDistricts = [];
              _stos = [];
            });
          },
          validator: (v) => v == null ? 'Pilih Region' : null,
        ),

        const SizedBox(height: 16),

        // District
        DropdownButtonFormField<String>(
          initialValue: _selectedDistrict,
          decoration: _dropdownDecoration('District'),
          hint: const Text('Pilih District'),
          items: _districts
              .map((d) => DropdownMenuItem(value: d, child: Text(d)))
              .toList(),
          onChanged: _selectedRegion == null
              ? null
              : (value) {
                  setState(() {
                    _selectedDistrict = value;
                    _selectedSubDistrict = null;
                    _selectedSto = null;
                    _subDistricts = (_stoData[_selectedRegion][value]
                            as Map<String, dynamic>)
                        .keys
                        .toList()
                      ..sort();
                    _stos = [];
                  });
                },
          validator: (v) => v == null ? 'Pilih District' : null,
        ),

        const SizedBox(height: 16),

        // Sub District
        DropdownButtonFormField<String>(
          initialValue: _selectedSubDistrict,
          decoration: _dropdownDecoration('Sub District'),
          hint: const Text('Pilih Sub District'),
          items: _subDistricts
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: _selectedDistrict == null
              ? null
              : (value) {
                  setState(() {
                    _selectedSubDistrict = value;
                    _selectedSto = null;
                    _stos = List<String>.from(
                      _stoData[_selectedRegion][_selectedDistrict][value]
                          as List,
                    )..sort();
                  });
                },
          validator: (v) => v == null ? 'Pilih Sub District' : null,
        ),

        const SizedBox(height: 16),

        // STO Terdekat
        DropdownButtonFormField<String>(
          initialValue: _selectedSto,
          decoration: _dropdownDecoration('STO Terdekat'),
          hint: const Text('Pilih STO Terdekat'),
          items: _stos
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: _selectedSubDistrict == null
              ? null
              : (value) {
                  setState(() {
                    _selectedSto = value;
                  });
                  if (value != null) {
                    widget.onChanged(
                      _selectedRegion!,
                      _selectedDistrict!,
                      _selectedSubDistrict!,
                      value,
                    );
                  }
                },
          validator: (v) => v == null ? 'Pilih STO Terdekat' : null,
        ),
      ],
    );
  }
}
