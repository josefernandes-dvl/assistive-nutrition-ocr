import 'package:flutter/material.dart';
import 'camera_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Assistive Nutrition OCR"),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              const Icon(
                Icons.food_bank,
                size: 100,
                color: Colors.green,
              ),

              const SizedBox(height: 30),

              const Text(
                "Analise rótulos de alimentos\ncom inteligência artificial",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),

              const SizedBox(height: 40),

              ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text("Tirar foto do rótulo"),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CameraScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              ElevatedButton.icon(
                icon: const Icon(Icons.image),
                label: const Text("Escolher imagem"),
                onPressed: () {
                  // implementar depois
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}