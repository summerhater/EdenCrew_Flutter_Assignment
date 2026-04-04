import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../theme/app_assets.dart';
import '../../../../theme/app_theme.dart';
import '../layout/search_layout_spec.dart';

class SearchToast extends StatelessWidget {
  const SearchToast({required this.layout, required this.message, super.key});

  final SearchLayoutSpec layout;
  final String message;

  @override
  Widget build(BuildContext context) {
    // TODO(assignment): Rebuild the toast shell to match Figma.
    // Expected structure:
    // - ClipRRect + BackdropFilter
    // - blurred glass background with border/shadow
    // - 20x20 heart + check composition
    // - message text styling that matches the design

    // [이전 구현 — 주석 처리]
    // return Container(
    //   height: SearchLayoutSpec.toastHeight,
    //   padding: EdgeInsets.symmetric(horizontal: 16 * layout.horizontalScale),
    //   decoration: BoxDecoration(
    //     color: AppColors.bg.bg_2_212121,
    //     borderRadius: BorderRadius.circular(16),
    //   ),
    //   child: Row(
    //     children: [
    //       SizedBox(
    //         key: const Key('search-toast-favorite-icon'),
    //         width: 20,
    //         height: 20,
    //         child: AppAssetSlotIcon(
    //           assetPath: AppAssets.favoriteHeart,
    //           slotWidth: 20,
    //           slotHeight: 20,
    //           assetWidth: AppAssetSizes.favoriteHeart.width,
    //           assetHeight: AppAssetSizes.favoriteHeart.height,
    //           color: AppColors.mainAndAccent.up_f93f62,
    //         ),
    //       ),
    //       const SizedBox(width: 12),
    //       Expanded(
    //         child: Text(
    //         message,
    //         style: AppTypography.searchToast,
    //         maxLines: 1,
    //         overflow: TextOverflow.ellipsis,
    //         ),
    //       ),
    //     ],
    //   ),
    // );

    // Note(assignment): boxShadow를 ClipRRect 외부 Container에 배치 — ClipRRect
    // 내부에 두면 shadow가 clip에 잘려 glow 효과가 표시되지 않기 때문.
    return Container(
      height: SearchLayoutSpec.toastHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            // figma 기준으로는 000000/25%(0x40000000)으로
            // 되어 있어 구현. 하지만 골든 테스트 기준 이미지에는 BoxShadow 없음.
            color: Color(0x40000000),
            offset: Offset(0, 2),
            blurRadius: 10,
          ),
        ],
      ),
      // ClipRRect를 BackdropFilter 외부에 감싸야 blurred glass
      // 효과가 toast 경계 밖으로 번지지 않음
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 16 * layout.horizontalScale,
            ),
            decoration: BoxDecoration(
              color: AppDerivedColors.searchToastBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppDerivedColors.searchToastBorder),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  // Stack으로 하트 위에 체크 overlay
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AppAssetSlotIcon(
                        key: const Key('search-toast-favorite-icon'),
                        assetPath: AppAssets.favoriteHeart,
                        slotWidth: 20,
                        slotHeight: 20,
                        assetWidth: AppAssetSizes.favoriteHeart.width,
                        assetHeight: AppAssetSizes.favoriteHeart.height,
                        color: AppColors.mainAndAccent.up_f93f62,
                      ),
                      Positioned(
                        // figma 기준 체크아이콘 위치 : 하트 정가운데 X
                        // 정가운데에서 figma와 유사하게 position 1px씩 미세 조정
                        right: 10 - (AppAssetSizes.toastCheck.width / 2) - 1,
                        bottom: 10 - (AppAssetSizes.toastCheck.height / 2) + 1,
                        child: AppSvgIcon(
                          key: const Key('search-toast-check-icon'),
                          assetPath: AppAssets.toastCheck,
                          width: AppAssetSizes.toastCheck.width,
                          height: AppAssetSizes.toastCheck.height,
                          color: AppColors.grays.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  // message가 외부 주입이므로 split으로
                  // 키워드를 분리해서 피그마 기준으로 색상 따로 적용
                  child: Text.rich(
                    TextSpan(
                      style: AppTypography.searchToast,
                      children: [
                        TextSpan(text: message.split('에 추가되었습니다.')[0]),
                        TextSpan(
                          text: '에 추가되었습니다.',
                          style: AppTypography.searchToast.copyWith(
                            color: AppColors.text.text_3_9e9e9e,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
