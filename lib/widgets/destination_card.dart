import 'package:flutter/material.dart';

class DestinationCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String category;
  final VoidCallback onTap;

  const DestinationCard(
      {required this.title,
      required this.subtitle,
      required this.category,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                  width: 96,
                  height: 72,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10))),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(title,
                                style: TextStyle(fontWeight: FontWeight.w600))),
                        Chip(
                            label:
                                Text(category, style: TextStyle(fontSize: 12)))
                      ]),
                      SizedBox(height: 6),
                      Text(subtitle, style: TextStyle(color: Colors.grey[700])),
                      SizedBox(height: 8),
                      Row(children: [
                        ElevatedButton.icon(
                            onPressed: () {},
                            icon: Icon(Icons.map),
                            label: Text('View Details'),
                            style: ElevatedButton.styleFrom(
                                minimumSize: Size(110, 36))),
                        SizedBox(width: 8),
                        OutlinedButton.icon(
                            onPressed: () {},
                            icon: Icon(Icons.add),
                            label: Text('Add to Route')),
                      ])
                    ]),
              )
            ],
          ),
        ),
      ),
    );
  }
}
