import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PokemonDetailScreen extends StatefulWidget {
  final int pokemonId;
  final String pokemonName;
  final String imageUrl;

  const PokemonDetailScreen({
    super.key,
    required this.pokemonId,
    required this.pokemonName,
    required this.imageUrl,
  });

  @override
  State<PokemonDetailScreen> createState() => _PokemonDetailScreenState();
}

class _PokemonDetailScreenState extends State<PokemonDetailScreen> {
  bool isLoading = true;
  String description = '';
  String weight = '';
  String height = '';
  List<String> types = [];
  List<Map<String, dynamic>> evolutions = [];

  @override
  void initState() {
    super.initState();
    fetchPokemonDetails();
  }

  Future<void> fetchPokemonDetails() async {
    try {
      final detailsResponse = await http.get(Uri.parse('https://pokeapi.co/api/v2/pokemon/${widget.pokemonId}'));
      final detailsData = json.decode(detailsResponse.body);

      height = '${(detailsData['height'] / 10).toStringAsFixed(1)} m';
      weight = '${(detailsData['weight'] / 10).toStringAsFixed(1)} kg';
      types = (detailsData['types'] as List).map((t) => t['type']['name'].toString()).toList();

      final speciesResponse = await http.get(Uri.parse('https://pokeapi.co/api/v2/pokemon-species/${widget.pokemonId}'));
      final speciesData = json.decode(speciesResponse.body);

      final flavorTextEntries = speciesData['flavor_text_entries'] as List;
      final englishEntry = flavorTextEntries.firstWhere(
        (entry) => entry['language']['name'] == 'en',
        orElse: () => flavorTextEntries[0],
      );
      description = englishEntry['flavor_text'].replaceAll('\n', ' ').replaceAll('\f', ' ');

      final evolutionUrl = speciesData['evolution_chain']['url'];
      final evolutionResponse = await http.get(Uri.parse(evolutionUrl));
      final evolutionData = json.decode(evolutionResponse.body);

      evolutions = _parseEvolutions(evolutionData['chain']);

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        description = 'Erro ao carregar os detalhes.';
      });
    }
  }

  List<Map<String, dynamic>> _parseEvolutions(Map<String, dynamic> chain) {
    List<Map<String, dynamic>> evoList = [];
    var current = chain;

    while (current.containsKey('evolves_to') && current['evolves_to'].isNotEmpty) {
      var nextEvo = current['evolves_to'][0];
      
      String currentUrl = current['species']['url'];
      String nextUrl = nextEvo['species']['url'];
      String currentId = currentUrl.split('/')[6];
      String nextId = nextUrl.split('/')[6];
      
      String minLevel = '??';
      if (nextEvo['evolution_details'].isNotEmpty && nextEvo['evolution_details'][0]['min_level'] != null) {
        minLevel = 'Lvl ${nextEvo['evolution_details'][0]['min_level']}';
      }

      evoList.add({
        'from_name': current['species']['name'],
        'from_id': currentId,
        'to_name': nextEvo['species']['name'],
        'to_id': nextId,
        'level': minLevel,
      });

      current = nextEvo; 
    }
    return evoList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red[700],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border, color: Colors.white),
            onPressed: () {}, 
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.yellowAccent))
          : Stack(
              children: [
                Positioned(
                  top: 10, left: 20, right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(widget.pokemonName.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                          Text('#${widget.pokemonId.toString().padLeft(3, '0')}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: types.map((type) => Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white54)),
                          child: Text(type.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        )).toList(),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blueGrey[900],
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40)),
                      border: const Border(top: BorderSide(color: Colors.orangeAccent, width: 4)),
                    ),
                    child: DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          const SizedBox(height: 40),
                          const TabBar(
                            indicatorColor: Colors.yellowAccent, labelColor: Colors.white, unselectedLabelColor: Colors.grey,
                            tabs: [Tab(text: 'Sobre'), Tab(text: 'Evolução')],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [_buildAboutTab(), _buildEvolutionTab()],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.12,
                  left: MediaQuery.of(context).size.width * 0.2, right: MediaQuery.of(context).size.width * 0.2,
                  child: Image.network(widget.imageUrl, height: 220, fit: BoxFit.contain),
                ),
              ],
            ),
    );
  }

  Widget _buildAboutTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(description, style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5)),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.cyan.withOpacity(0.3))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('Altura', style: TextStyle(color: Colors.grey, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(height, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  children: [
                    const Text('Peso', style: TextStyle(color: Colors.grey, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(weight, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvolutionTab() {
    if (evolutions.isEmpty) return const Center(child: Text('Este Pokémon não possui evoluções.', style: TextStyle(color: Colors.white70)));
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: evolutions.length,
      itemBuilder: (context, index) {
        final evo = evolutions[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildEvoItem(evo['from_name'], evo['from_id']),
              Column(
                children: [
                  const Icon(Icons.arrow_forward, color: Colors.yellowAccent),
                  Text(evo['level'], style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                ],
              ),
              _buildEvoItem(evo['to_name'], evo['to_id']),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEvoItem(String name, String id) {
    return Column(
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: Colors.white12, shape: BoxShape.circle, border: Border.all(color: Colors.orangeAccent)),
          child: Image.network('https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$id.png', fit: BoxFit.contain),
        ),
        const SizedBox(height: 8),
        Text(name.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }
}