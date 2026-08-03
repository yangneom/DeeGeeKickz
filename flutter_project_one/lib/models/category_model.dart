/// Represents a single featured category card shown in the
/// "Featured Categories" bento grid section on the landing page.
///
/// [filterValue] is what actually gets pushed into ShopFilterState
/// when a tile is tapped — kept separate from [name] so the display
/// copy can stay punchy ("Everyday Essentials") while still mapping
/// cleanly onto the real category values used for filtering/sorting
/// on the backend ("Casual").
class CategoryModel {
  final String id;
  final String name;
  final String tagline;
  final String imageUrl;
  final String filterValue;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.tagline,
    required this.imageUrl,
    required this.filterValue,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      tagline: json['tagline'] as String,
      imageUrl: json['imageUrl'] as String,
      filterValue: json['filterValue'] as String? ?? json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'tagline': tagline,
      'imageUrl': imageUrl,
      'filterValue': filterValue,
    };
  }
}

/// ---------------------------------------------------------------
/// FEATURED CATEGORIES — now aligned to the real shop taxonomy:
/// Running Shoe / Casual / Sneakers. filterValue MUST exactly match
/// the category strings stored on Product.category in the backend
/// (see lib/models/product.dart), or the tap-through filter on the
/// Shop screen will silently return zero results.
///
/// Images below are carried over from the previous mock set as
/// placeholders — swap for real product photography via
/// services/admin/inventory/ImageService.dart before shipping.
/// ---------------------------------------------------------------
const List<CategoryModel> mockFeaturedCategories = [
  CategoryModel(
    id: 'cat_running',
    name: 'Running',
    tagline: 'Performance first →',
    filterValue: 'Running Shoe',
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuBlD40Um8TE91TCPvUcQ0a0GBQq2HZhFF4IGRdxkOmfsL62T784zqQsAw3QZf_w578SOdYEIYRYnfmNZBjBww2dcuBTDqPjfSo_TZF5wKOxiKh0Krat8zaCnHsVELpZKEox-E6l4ALGdTOkBCopQY1OMOgifqBuhFhSwrdiELwnqNHtfDTM63bf4dYuHP60IXuWgFF09y2tHNSuIvS2x92WQIht79Rrh22Mo43EJVZBfeoebboGEjfjxtW4HAsWnRC42c1-QpOt0EE',
  ),
  CategoryModel(
    id: 'cat_casual',
    name: 'Casual',
    tagline: 'Everyday precision →',
    filterValue: 'Casual',
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuD2nq1bEKwWqfmRosEfsjbFAvm_gBimvIoXpv6ySwwaT2ZI9mXxSpGtE09pJgFLdYGkDPqLRQJchc_MadcolmoWCDyj0zCM8SYnpDg-saNMgH3WtjSzwi53OAHLjfo3wecl0LLsNfU3x8lysukBvJy0ypfliZXJ90bOOi-RN-Oxbnhg-BLHGwcslvbqVYgNPo4hRytV2BEHyAv6OhhUF9dGuovUjCTodq8uwkwqZZZCdwQ7ZyAxaIcyt2-eEl9J_jB48nxZe95Y0f0',
  ),
  CategoryModel(
    id: 'cat_sneakers',
    name: 'Sneakers',
    tagline: 'Elevate your rotation →',
    filterValue: 'Sneakers',
    imageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuC-JbwRTNpkyy20uFIBjubBSrTr5erO5xyNrKIzJ6DNQVFy33YzzormPR_RvfrcavQyGXbG0uOAxsGL3XF0ax2f0_8dnZ6ge0yDl8hvlvFvTdy8RDojAQumqanL_VTE_jx0qpHrY3e4CBmVg2IQdz8qiwUd5Q5qTQU5p9_Bq3n9JsUeR2g_SNdsV6_QmJJSAbGR2Zvqex6GVeZTTvAGisQNG9LaGJGKIi-IGQjjCYVcGgBvpV-xNMuOSflOT6ZVJfv0tUDoffCsRvE',
  ),
];