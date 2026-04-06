import 'package:flutter/material.dart';

import '../../../watchlist/domain/models/watchlist_models.dart';
import '../../../../theme/app_assets.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/services/search_text_utils.dart';
import '../layout/search_layout_spec.dart';
import 'search_action_bar.dart';

class SearchResultRow extends StatelessWidget {
  const SearchResultRow({
    required this.item,
    required this.query,
    required this.isSelected,
    required this.layout,
    required this.onTap,
    required this.onHeartTap,
    required this.onActionTap,
    super.key,
  });

  final StockSearchItem item;
  final String query;
  final bool isSelected;
  final SearchLayoutSpec layout;
  final VoidCallback onTap;
  final VoidCallback onHeartTap;
  final ValueChanged<String> onActionTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('search-result-${item.id}'),
        onTap: onTap,
        child: Column(
          children: [
            SizedBox(
              key: Key('search-result-row-${item.id}'),
              height: SearchLayoutSpec.resultRowHeight,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: layout.horizontalPadding,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _SearchTextColumn(item: item, query: query),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      key: Key('search-heart-${item.id}'),
                      onTap: onHeartTap,
                      behavior: HitTestBehavior.opaque,
                      child: AppAssetSlotIcon(
                        key: Key('search-heart-icon-${item.id}'),
                        assetPath: AppAssets.favoriteHeart,
                        // TODO(assignment): Match the exact Figma slot size.
                        // This starter keeps the slot slightly oversized so
                        // the related widget test can guide the fix.

                        // figma에 맞게 20으로 slot size 변경
                        slotWidth: 20,
                        slotHeight: 20,
                        assetWidth: AppAssetSizes.favoriteHeart.width,
                        assetHeight: AppAssetSizes.favoriteHeart.height,
                        color: item.isFavorite
                            ? AppColors.mainAndAccent.up_f93f62
                            : AppColors.darkTheme.c_424242,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: layout.horizontalPadding,
                ),
                // child: Container(
                //   key: Key('search-actions-${item.id}'),
                //   height: SearchLayoutSpec.expandedActionHeight,
                //   alignment: Alignment.center,
                //   decoration: BoxDecoration(
                //     color: AppColors.bg.bg_2_212121,
                //     borderRadius: BorderRadius.circular(4),
                //     border: Border.all(color: AppColors.border.border_5_3b3e53),
                //   ),
                //   child: InkWell(
                //     onTap: () => onActionTap('TODO'),
                //     child: Center(
                //       child: Text(
                //         'TODO(assignment): SearchActionBar를 Figma 기준으로 재구성하세요.',
                //         style: AppTypography.searchMeta,
                //         textAlign: TextAlign.center,
                //       ),
                //     ),
                //   ),

                // 이전 코드에서 Container에 붙어있던 key를
                // 그대로 유지, SearchActionBar가 Stateless라 상태 추적 목적으로
                // key가 불필요하지만 기존 코드의 의도를 따르고 향후 Stateful로
                // 변경될 가능성을 고려해 그대로 명시
                child: SearchActionBar(
                  key: Key('search-actions-${item.id}'),
                  layout: layout,
                  onActionTap: onActionTap,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchTextColumn extends StatelessWidget {
  const _SearchTextColumn({required this.item, required this.query});

  final StockSearchItem item;
  final String query;

  @override
  Widget build(BuildContext context) {
    // TODO(assignment): Rebuild this text block to match Figma.
    // Expected shape:
    // - title + subtitle as two RichText widgets
    // - query highlight using splitSearchTextParts()
    // - typography and ellipsis should match the design

    // final hasQuery = query.trim().isNotEmpty;
    // return Column(
    //   mainAxisAlignment: MainAxisAlignment.center,
    //   crossAxisAlignment: CrossAxisAlignment.start,
    //   children: [
    //     Text(
    //       item.name,
    //       style: hasQuery
    //           ? AppTypography.searchName.copyWith(decoration: TextDecoration.none)
    //           : AppTypography.searchName,
    //       maxLines: 1,
    //       overflow: TextOverflow.ellipsis,
    //     ),
    //     const SizedBox(height: 4),
    //     Text(
    //       buildSearchSubtitle(item),
    //       style: AppTypography.searchMeta,
    //       maxLines: 1,
    //       overflow: TextOverflow.ellipsis,
    //     ),
    //   ],
    // );

    // splitSearchTextParts가 빈 query를 하이라이트하지 않은
    // 파트로 반환하므로 hasQuery 분기 없이 동일 경로로 처리
    final titleParts = splitSearchTextParts(item.name, query);
    final subtitleParts = splitSearchTextParts(buildSearchSubtitle(item), query);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            children: titleParts
                .map(
                  (part) => TextSpan(
                    text: part.text,
                    // 검색어 하이라이트만 색상 교체
                    style: part.isHighlighted
                        ? AppTypography.searchName.copyWith(
                            color: AppColors.mainAndAccent.point_b980ff,
                          )
                        : AppTypography.searchName,
                  ),
                )
                .toList(growable: false),
          ),
        ),
        const SizedBox(height: 4),
        RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            children: subtitleParts.expand((part) {
              // 검색어 하이라이트만 색상 교체
              final baseStyle = part.isHighlighted
                  ? AppTypography.searchMeta.copyWith(color: AppColors.mainAndAccent.point_b980ff)
                  : AppTypography.searchMeta;

              // figma 기준 Subtitle에서 '|' 구분선만 색상이 다르므로 색상 적용을 위해 split
              final subSplit = part.text.split('|');

              // buildSearchSubtitle에서 무조건 '|'을 포함해 반환하지만,
              // 만약 어떤 이유로든 | 가 없다면 기본 searchMeta 스타일 적용
              if (subSplit.length < 2) {
                return [TextSpan(text: part.text, style: baseStyle)];
              }

              // '|' 구분선만 색상 변경해서 반환
              return [
                TextSpan(text: subSplit[0], style: baseStyle),
                TextSpan(
                  text: '|',
                  style: baseStyle.copyWith(
                    color: AppColors.border.border_4_424242,
                  ),
                ),
                TextSpan(text: subSplit[1], style: baseStyle),
              ];
            }).toList(growable: false)
          ),
        ),
      ],
    );
  }
}
