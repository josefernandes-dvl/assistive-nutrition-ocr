import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/ingredient.dart';

class IngredientCard extends StatelessWidget {
  final Ingredient ingredient;

  const IngredientCard({super.key, required this.ingredient});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: ingredient.isFlagged
            ? AppTheme.dangerRed.withValues(alpha: 0.08)
            : AppTheme.safeGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ingredient.isFlagged
              ? AppTheme.dangerRed.withValues(alpha: 0.3)
              : AppTheme.safeGreen.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: ListTile(
        leading: Icon(
          ingredient.isFlagged
              ? Icons.warning_amber_rounded
              : Icons.check_circle_outline,
          color: ingredient.isFlagged ? AppTheme.dangerRed : AppTheme.safeGreen,
          size: 28,
        ),
        title: Text(
          ingredient.name,
          style: TextStyle(
            fontWeight:
                ingredient.isFlagged ? FontWeight.bold : FontWeight.normal,
            color: ingredient.isFlagged ? AppTheme.dangerRed : AppTheme.textPrimary,
          ),
        ),
        subtitle: ingredient.isFlagged && ingredient.flagReason != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: ingredient.flagReason!
                    .split(' · ')
                    .map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '• $r',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.dangerRed.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              )
            : null,
        trailing: ingredient.isFlagged
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.dangerRed,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'ALERTA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : const Icon(
                Icons.verified,
                color: AppTheme.safeGreen,
                size: 20,
              ),
      ),
    );
  }
}
