import 'package:flutter/material.dart';

import '../generated/w3c_test_catalog.dart';
import '../w3c/w3c_source_loader.dart';
import 'custom_svg_viewer_page.dart';

class W3cPlaygroundPage extends StatefulWidget {
  const W3cPlaygroundPage({super.key});

  @override
  State<W3cPlaygroundPage> createState() => _W3cPlaygroundPageState();
}

class _W3cPlaygroundPageState extends State<W3cPlaygroundPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _category = 'all';
  bool _onlyStaticAccepted = false;
  String? _loadingCaseName;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _categories {
    final values = <String>{'all'};
    for (final item in kW3cPlaygroundCases) {
      values.add(item.category);
    }
    final ordered = values.toList()..sort();
    return ordered;
  }

  List<W3cPlaygroundCase> get _filteredCases {
    return kW3cPlaygroundCases
        .where((item) {
          if (_onlyStaticAccepted && !item.inStaticAccepted) {
            return false;
          }
          if (_category != 'all' && item.category != _category) {
            return false;
          }
          if (_query.isEmpty) {
            return true;
          }
          return item.name.toLowerCase().contains(_query) ||
              item.category.toLowerCase().contains(_query);
        })
        .toList(growable: false);
  }

  Future<void> _openCase(W3cPlaygroundCase item) async {
    setState(() {
      _loadingCaseName = item.name;
    });

    try {
      final source = await loadW3cSvgSource(item.svgPath);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CustomSvgViewerPage(
            initialSvgSource: source,
            initialCaseName: item.name,
            initialCaseSvgPath: item.svgPath,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load ${item.name}: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingCaseName = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCases;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('W3C Playground')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'All: $kW3cPlaygroundTotalCount',
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        'Static accepted: $kW3cPlaygroundStaticAcceptedCount',
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        'Showing: ${filtered.length}',
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          labelText: 'Search by test name or category',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 760;
                          final categoryPicker =
                              DropdownButtonFormField<String>(
                                initialValue: _category,
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                  prefixIcon: Icon(Icons.filter_list),
                                ),
                                items: _categories
                                    .map(
                                      (value) => DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  setState(() {
                                    _category = value;
                                  });
                                },
                              );

                          final staticChip = FilterChip(
                            label: const Text('Only static accepted'),
                            selected: _onlyStaticAccepted,
                            onSelected: (selected) {
                              setState(() {
                                _onlyStaticAccepted = selected;
                              });
                            },
                          );

                          if (compact) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                categoryPicker,
                                const SizedBox(height: 10),
                                staticChip,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: categoryPicker),
                              const SizedBox(width: 12),
                              staticChip,
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Card(
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final isLoading = _loadingCaseName == item.name;
                      return ListTile(
                        dense: true,
                        title: Text(item.name),
                        subtitle: Text(
                          '${item.category} • ${item.inStaticAccepted ? 'static accepted' : 'full suite'}',
                        ),
                        leading: Icon(
                          item.inStaticAccepted
                              ? Icons.verified_outlined
                              : Icons.science_outlined,
                        ),
                        trailing: isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.open_in_new),
                        onTap: isLoading ? null : () => _openCase(item),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
