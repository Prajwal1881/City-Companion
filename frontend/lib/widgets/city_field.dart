import 'package:flutter/material.dart';

const kIndiaCities = [
  'Agra', 'Ahmedabad', 'Aizawl', 'Ajmer', 'Akola', 'Aligarh', 'Allahabad',
  'Alwar', 'Ambala', 'Ambattur', 'Amravati', 'Amritsar', 'Anantapur',
  'Aurangabad', 'Bangalore', 'Bareilly', 'Belgaum', 'Bellary', 'Bhavnagar',
  'Bhilai', 'Bhiwandi', 'Bhopal', 'Bhubaneswar', 'Bikaner', 'Bilaspur',
  'Bokaro Steel City', 'Chandigarh', 'Chennai', 'Coimbatore', 'Cuttack',
  'Davanagere', 'Dehradun', 'Delhi', 'Dhanbad', 'Durgapur', 'Erode',
  'Faridabad', 'Firozabad', 'Ghaziabad', 'Gorakhpur', 'Gulbarga', 'Guntur',
  'Gurgaon', 'Guwahati', 'Gwalior', 'Hubli', 'Hyderabad', 'Imphal',
  'Indore', 'Jabalpur', 'Jaipur', 'Jalandhar', 'Jammu', 'Jamnagar',
  'Jamshedpur', 'Jhansi', 'Jodhpur', 'Kannur', 'Kanpur', 'Kakinada',
  'Kochi', 'Kolhapur', 'Kolkata', 'Kollam', 'Kota', 'Kozhikode',
  'Kurnool', 'Lucknow', 'Ludhiana', 'Madurai', 'Malegaon', 'Mangalore',
  'Meerut', 'Moradabad', 'Mumbai', 'Mysore', 'Nagpur', 'Nashik',
  'Navi Mumbai', 'Noida', 'Patna', 'Pimpri-Chinchwad', 'Pune', 'Raipur',
  'Rajkot', 'Ranchi', 'Salem', 'Sangli', 'Shimla', 'Siliguri', 'Solapur',
  'Srinagar', 'Surat', 'Thane', 'Thiruvananthapuram', 'Tiruchirappalli',
  'Tirunelveli', 'Tirupati', 'Tirupur', 'Udaipur', 'Ujjain', 'Vadodara',
  'Varanasi', 'Vijayawada', 'Visakhapatnam', 'Warangal',
];

class CityField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const CityField({super.key, required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue value) {
        if (value.text.isEmpty) return const [];
        final q = value.text.toLowerCase();
        return kIndiaCities.where((c) => c.toLowerCase().contains(q));
      },
      onSelected: (city) => controller.text = city,
      fieldViewBuilder: (context, textCtrl, focusNode, onSubmitted) {
        textCtrl.text = controller.text;
        textCtrl.addListener(() => controller.text = textCtrl.text);
        return TextField(
          controller: textCtrl,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          ),
          onSubmitted: (_) => onSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final city = options.elementAt(i);
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_city_outlined, size: 18),
                    title: Text(city),
                    onTap: () => onSelected(city),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
