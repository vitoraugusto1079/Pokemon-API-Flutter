import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'pokemon_detail_screen.dart'; 

// ==========================================
// CONTROLE GLOBAL DE TEMA
// ==========================================
// Usamos um ValueNotifier para alternar o tema de qualquer lugar do app
final ValueNotifier<bool> isRedTheme = ValueNotifier<bool>(false);

void main() {
  runApp(const PokedexApp());
}

class PokedexApp extends StatelessWidget {
  const PokedexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isRedTheme,
      builder: (context, isRed, child) {
        return MaterialApp(
          title: 'Pokédex',
          debugShowCheckedModeBanner: false,
          theme: isRed
              ? ThemeData(
                  scaffoldBackgroundColor: Colors.red[700], // Tema Vermelho
                  fontFamily: 'Arial',
                  dialogBackgroundColor: Colors.red[800], // Fundo dos popups no tema vermelho
                  textTheme: const TextTheme(
                    bodyLarge: TextStyle(color: Colors.white),
                    bodyMedium: TextStyle(color: Colors.white),
                  ),
                )
              : ThemeData(
                  scaffoldBackgroundColor: const Color(0xFFF5F5F5), // Tema Branco/Claro
                  fontFamily: 'Arial',
                  dialogBackgroundColor: Colors.white,
                ),
          home: const PokedexScreen(),
        );
      },
    );
  }
}

// ==========================================
// MODELO DE DADOS
// ==========================================
class Pokemon {
  final int id;
  final String name;
  final String imageUrl;
  final List<String> types;

  Pokemon({
    required this.id, 
    required this.name, 
    required this.imageUrl,
    required this.types,
  });
}

// ==========================================
// TELA PRINCIPAL
// ==========================================
class PokedexScreen extends StatefulWidget {
  const PokedexScreen({super.key});

  @override
  State<PokedexScreen> createState() => _PokedexScreenState();
}

class _PokedexScreenState extends State<PokedexScreen> {
  List<Pokemon> pokemonList = [];
  bool isLoading = false;
  String errorMessage = '';
  final TextEditingController _searchController = TextEditingController();

  // Variáveis para guardar o estado da geração atual
  int currentOffset = 0;
  String currentGenerationName = "Geração 1";

  @override
  void initState() {
    super.initState();
    fetchInitialPokemon();
  }

  // LÓGICA: Buscar Lista (Com suporte a paginação de gerações)
  Future<void> fetchInitialPokemon({int offset = 0}) async {
    setState(() {
      isLoading = true;
      errorMessage = '';
      currentOffset = offset;
    });

    try {
      // Limitamos a 20 para carregar rápido, mas mudamos o ponto de partida (offset)
      final response = await http.get(Uri.parse('https://pokeapi.co/api/v2/pokemon?limit=20&offset=$offset'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'];

        List<Future<Pokemon>> futures = results.map<Future<Pokemon>>((pokeData) async {
          final detailResponse = await http.get(Uri.parse(pokeData['url']));
          final detailData = json.decode(detailResponse.body);
          
          final types = (detailData['types'] as List)
              .map((t) => t['type']['name'].toString())
              .toList();

          return Pokemon(
            id: detailData['id'],
            name: detailData['name'],
            imageUrl: 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/${detailData['id']}.png',
            types: types,
          );
        }).toList();

        final loadedPokemon = await Future.wait(futures);

        setState(() {
          pokemonList = loadedPokemon;
        });
      } else {
        setState(() => errorMessage = 'Erro ao carregar a Pokédex.');
      }
    } catch (e) {
      setState(() => errorMessage = 'Erro de conexão. Verifique sua internet.');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> searchPokemon(String query) async {
    if (query.trim().isEmpty) {
      fetchInitialPokemon(offset: currentOffset); // Volta para a geração que estava
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
      pokemonList = [];
    });

    try {
      final searchQuery = query.trim().toLowerCase();
      final response = await http.get(Uri.parse('https://pokeapi.co/api/v2/pokemon/$searchQuery'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final types = (data['types'] as List).map((t) => t['type']['name'].toString()).toList();
        
        setState(() {
          pokemonList = [
            Pokemon(
              id: data['id'],
              name: data['name'],
              imageUrl: data['sprites']['other']['official-artwork']['front_default'] ?? '',
              types: types,
            )
          ];
        });
      } else if (response.statusCode == 404) {
        setState(() => errorMessage = 'Pokémon não encontrado!');
      } else {
        setState(() => errorMessage = 'Ocorreu um erro na busca.');
      }
    } catch (e) {
      setState(() => errorMessage = 'Dispositivo offline ou erro de rede.');
    } finally {
      setState(() => isLoading = false);
    }
  }

  // DIÁLOGO PARA SELECIONAR A GERAÇÃO
  void _showGenerationDialog() {
    // Definimos a cor do texto do popup baseada no tema
    Color textColor = isRedTheme.value ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Selecione a Geração', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildGenOption('Geração 1 (Kanto)', 0, textColor),
                _buildGenOption('Geração 2 (Johto)', 151, textColor),
                _buildGenOption('Geração 3 (Hoenn)', 251, textColor),
                _buildGenOption('Geração 4 (Sinnoh)', 386, textColor),
                _buildGenOption('Geração 5 (Unova)', 493, textColor),
              ],
            ),
          ),
        );
      },
    );
  }

  // WIDGET AUXILIAR PARA O MENU DE GERAÇÕES
  Widget _buildGenOption(String title, int offset, Color textColor) {
    return ListTile(
      title: Text(title, style: TextStyle(color: textColor)),
      onTap: () {
        Navigator.pop(context); // Fecha o modal
        setState(() {
          currentGenerationName = title.split(' ')[0] + " " + title.split(' ')[1]; // Ex: "Geração 1"
        });
        fetchInitialPokemon(offset: offset); // Busca os pokemon dessa geração
      },
    );
  }

  Color _getColorFromType(String type) {
    switch (type.toLowerCase()) {
      case 'grass': return const Color(0xFF48D0B0);
      case 'fire': return const Color(0xFFFB6C6C);
      case 'water': return const Color(0xFF76BDFE);
      case 'bug': return const Color(0xFF8BD674);
      case 'normal': return const Color(0xFFB5B9C4);
      case 'poison': return const Color(0xFF9F5BBA);
      case 'electric': return const Color(0xFFFFCE4B);
      case 'ground': return const Color(0xFFE2BF65);
      case 'fairy': return const Color(0xFFECA8CE);
      case 'fighting': return const Color(0xFFC03028);
      case 'psychic': return const Color(0xFFF85888);
      case 'rock': return const Color(0xFFB8A038);
      case 'ghost': return const Color(0xFF705898);
      case 'dragon': return const Color(0xFF7038F8);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Definimos cores dinâmicas para os textos baseadas no tema selecionado
    final Color textColor = isRedTheme.value ? Colors.white : Colors.black87;
    final Color searchBarColor = isRedTheme.value ? Colors.red[900]! : Colors.grey[200]!;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CABEÇALHO ATUALIZADO (Sem seta e com Menu funcional)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end, // Alinha o botão para a direita
                children: [
                  PopupMenuButton<String>(
                    icon: Icon(Icons.menu, color: textColor, size: 30),
                    color: isRedTheme.value ? Colors.red[800] : Colors.white,
                    onSelected: (value) {
                      if (value == 'theme') {
                        isRedTheme.value = !isRedTheme.value; // Alterna o tema
                      } else if (value == 'gen') {
                        _showGenerationDialog(); // Abre modal de gerações
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      PopupMenuItem(
                        value: 'theme',
                        child: Text(
                          isRedTheme.value ? 'Mudar para Tema Branco' : 'Mudar para Tema Vermelho',
                          style: TextStyle(color: textColor),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'gen',
                        child: Text('Ver por Geração', style: TextStyle(color: textColor)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Pokedex', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textColor)),
                  Text(currentGenerationName, style: TextStyle(fontSize: 16, color: textColor.withOpacity(0.7))),
                ],
              ),
            ),
            
            // BARRA DE PESQUISA (Cores dinâmicas)
            Padding(
              padding: const EdgeInsets.all(20),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'Buscar Pokémon...',
                  hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
                  prefixIcon: Icon(Icons.search, color: textColor.withOpacity(0.7)),
                  filled: true,
                  fillColor: searchBarColor,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (value) => searchPokemon(value),
              ),
            ),

            // CORPO COM GRID
            Expanded(
              child: _buildBodyContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: isRedTheme.value ? Colors.white : Colors.redAccent,
        ),
      );
    }
    
    if (errorMessage.isNotEmpty) {
      return Center(child: Text(errorMessage, style: TextStyle(fontSize: 16, color: isRedTheme.value ? Colors.white : Colors.black87)));
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.35, 
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: pokemonList.length,
      itemBuilder: (context, index) {
        final pokemon = pokemonList[index];
        return _buildGridCard(pokemon, context);
      },
    );
  }

  Widget _buildGridCard(Pokemon pokemon, BuildContext context) {
    Color cardColor = pokemon.types.isNotEmpty ? _getColorFromType(pokemon.types[0]) : Colors.grey;
    String capitalizedName = pokemon.name.substring(0, 1).toUpperCase() + pokemon.name.substring(1);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PokemonDetailScreen(
              pokemonId: pokemon.id,
              pokemonName: pokemon.name,
              imageUrl: pokemon.imageUrl,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: cardColor.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              bottom: -10,
              child: Icon(
                Icons.catching_pokemon, 
                size: 100, 
                color: Colors.white.withOpacity(0.2),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          capitalizedName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '#${pokemon.id.toString().padLeft(3, '0')}',
                        style: TextStyle(color: Colors.black.withOpacity(0.15), fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: pokemon.types.map((type) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        type.substring(0, 1).toUpperCase() + type.substring(1),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),

            Positioned(
              right: 4,
              bottom: 4,
              child: SizedBox(
                width: 75,
                height: 75,
                child: Image.network(
                  pokemon.imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.help_outline, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}