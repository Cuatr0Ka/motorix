/// Página de resultados de un listado de la API.
class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<T> items;
  final int total;
  final int page;
  final int pageSize;

  int get totalPages => total == 0 ? 1 : (total / pageSize).ceil();
  int get firstItem => total == 0 ? 0 : (page - 1) * pageSize + 1;
  int get lastItem => total == 0 ? 0 : (firstItem + items.length - 1);
}
