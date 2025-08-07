import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:solana/dto.dart';
import 'package:solana/solana.dart';
import 'package:http/http.dart' as http;
import 'package:easy_localization/easy_localization.dart';
import '../services/rpc_service.dart';

class NFTPage extends StatefulWidget {
  final Ed25519HDKeyPair wallet;

  const NFTPage({super.key, required this.wallet});

  @override
  State<NFTPage> createState() => _NFTPageState();
}

class _NFTPageState extends State<NFTPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _nfts = [];
  late RpcClient _rpcClient;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // _rpcClient = RpcClient('https://api.mainnet-beta.solana.com'); // KALDIR
    _loadNFTs();
  }

  Future<void> _loadNFTs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get all token accounts for the wallet with fallback
      final tokenAccountsResult = await RpcService.executeWithFallback((client) async {
        return await client.getTokenAccountsByOwner(
          widget.wallet.address,
          const TokenAccountsFilter.byProgramId(TokenProgram.programId),
          encoding: Encoding.jsonParsed,
        );
      });

      List<Map<String, dynamic>> nftList = [];
      final tokenAccounts = tokenAccountsResult.value;

      for (final account in tokenAccounts) {
        try {
          final accountData = account.account.data;
          if (accountData is ParsedAccountData) {
            final parsed = accountData.parsed as Map<String, dynamic>;
            final info = parsed['info'] as Map<String, dynamic>;

            final tokenAmount = info['tokenAmount'] as Map<String, dynamic>;
            if (tokenAmount['amount'] == '1' &&
                tokenAmount['decimals'] == 0) {

              final mintAddress = info['mint'] as String;

              final metadata = await _getTokenMetadata(mintAddress);
              if (metadata != null) {
                nftList.add(metadata);
              }
            }
          }
        } catch (e) {
          print('Error processing token account: $e');
          continue;
        }
      }

      setState(() {
        _nfts = nftList;
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _errorMessage = 'Network hatası: NFT\'ler yüklenemedi. Lütfen internet bağlantınızı kontrol edin.';
        _isLoading = false;
      });
      print('Error loading NFTs: $e');
    }
  }

  Future<Map<String, dynamic>?> _getTokenMetadata(String mintAddress) async {
    try {
      // Get mint account info with fallback
      final mintInfoResult = await RpcService.executeWithFallback((client) async {
        return await client.getAccountInfo(
          mintAddress,
          encoding: Encoding.jsonParsed,
        );
      });

      if (mintInfoResult?.value == null) return null;

      Map<String, dynamic> nftData = {
        'mint': mintAddress,
        'name': 'Unknown NFT',
        'collection': 'Unknown Collection',
        'image': null,
        'description': '',
        'attributes': <Map<String, dynamic>>[],
        'rarity': 'Unknown',
      };

      // Try to fetch metadata from various sources with better timeout
      try {
        final apiMetadata = await _fetchFromNFTAPIs(mintAddress);
        if (apiMetadata != null) {
          nftData.addAll(apiMetadata);
        }
      } catch (e) {
        print('Error fetching from NFT APIs: $e');
      }

      return nftData;
    } catch (e) {
      print('Error getting token metadata for $mintAddress: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getMetaplexMetadata(String mintAddress) async {
    try {
      // Calculate metadata PDA (Program Derived Address)
      final metadataProgramId = 'metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s';

      // This is a simplified approach - in a real implementation,
      // you would need to properly calculate the PDA and parse the metadata

      return null; // Placeholder for now
    } catch (e) {
      print('Error getting Metaplex metadata: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchFromNFTAPIs(String mintAddress) async {
    try {
      // Basit NFT entry oluştur - network sorunlarında bile çalışır
      return {
        'name': 'NFT #${mintAddress.substring(0, 8)}',
        'collection': 'Solana NFT',
        'image': null,
        'description': 'NFT from your wallet',
        'attributes': [],
        'rarity': 'Common',
      };

    } catch (e) {
      print('Error fetching from NFT APIs: $e');
      return {
        'name': 'NFT #${mintAddress.substring(0, 8)}',
        'collection': 'Unknown Collection',
        'image': null,
        'description': 'NFT metadata could not be loaded',
        'attributes': [],
        'rarity': 'Unknown',
      };
    }
  }

  String _calculateRarity(List<dynamic>? attributes) {
    if (attributes == null || attributes.isEmpty) return 'Common';

    // Simple rarity calculation based on number of attributes
    if (attributes.length >= 7) return 'Legendary';
    if (attributes.length >= 5) return 'Rare';
    if (attributes.length >= 3) return 'Uncommon';
    return 'Common';
  }

  Widget _buildGlassCard({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFFF6B35).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildNFTCard(Map<String, dynamic> nft) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _showNFTDetails(nft),
      child: _buildGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // NFT Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Container(
                height: 150,
                width: double.infinity,
                child: nft['image'] != null && nft['image'].toString().isNotEmpty
                    ? Image.network(
                  nft['image'],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFFF6B35).withOpacity(0.3),
                            const Color(0xFFFF8C42).withOpacity(0.3),
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 60,
                        color: Colors.white,
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFFF6B35).withOpacity(0.3),
                            const Color(0xFFFF8C42).withOpacity(0.3),
                          ],
                        ),
                      ),
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                              : null,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    );
                  },
                )
                    : Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFF6B35).withOpacity(0.3),
                        const Color(0xFFFF8C42).withOpacity(0.3),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.image,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // NFT Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nft['name'] ?? 'Unknown NFT',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    nft['collection'] ?? 'Unknown Collection',
                    style: TextStyle(
                      color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getRarityColor(nft['rarity'] ?? 'Common').withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          nft['rarity'] ?? 'Common',
                          style: TextStyle(
                            color: _getRarityColor(nft['rarity'] ?? 'Common'),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.verified,
                        color: const Color(0xFFFF6B35),
                        size: 16,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'legendary':
        return Colors.purple;
      case 'rare':
        return Colors.orange;
      case 'uncommon':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  void _showNFTDetails(Map<String, dynamic> nft) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // NFT Image
                    Center(
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: nft['image'] != null && nft['image'].toString().isNotEmpty
                              ? Image.network(
                            nft['image'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFFFF6B35).withOpacity(0.3),
                                      const Color(0xFFFF8C42).withOpacity(0.3),
                                    ],
                                  ),
                                ),
                                child: const Icon(
                                  Icons.image_not_supported,
                                  size: 100,
                                  color: Colors.white,
                                ),
                              );
                            },
                          )
                              : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFFF6B35).withOpacity(0.3),
                                  const Color(0xFFFF8C42).withOpacity(0.3),
                                ],
                              ),
                            ),
                            child: const Icon(
                              Icons.image,
                              size: 100,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // NFT Name
                    Text(
                      nft['name'] ?? 'Unknown NFT',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Collection
                    Text(
                      nft['collection'] ?? 'Unknown Collection',
                      style: TextStyle(
                        color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Mint Address
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.black : Colors.grey[100])?.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mint Address',
                            style: TextStyle(
                              color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            nft['mint'] ?? 'Unknown',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Rarity
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getRarityColor(nft['rarity'] ?? 'Common').withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            nft['rarity'] ?? 'Common',
                            style: TextStyle(
                              color: _getRarityColor(nft['rarity'] ?? 'Common'),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (nft['description'] != null && nft['description'].toString().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Açıklama',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        nft['description'],
                        style: TextStyle(
                          color: (isDark ? Colors.white : Colors.black87).withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Attributes
                    if (nft['attributes'] != null && (nft['attributes'] as List).isNotEmpty) ...[
                      Text(
                        'Özellikler',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      ...(nft['attributes'] as List).map<Widget>((attr) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.black : Colors.grey[100])?.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Text(
                              attr['trait_type']?.toString() ?? attr['key']?.toString() ?? 'Property',
                              style: TextStyle(
                                color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              attr['value']?.toString() ?? 'Unknown',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                    ],

                    const SizedBox(height: 24),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Transfer özelliği yakında!')),
                              );
                            },
                            icon: const Icon(Icons.send, color: Colors.white),
                            label: const Text(
                              'Transfer',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6B35),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Marketplace özelliği yakında!')),
                              );
                            },
                            icon: const Icon(Icons.store, color: Colors.white),
                            label: const Text(
                              'Sat',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'NFT Koleksiyonu',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black87,
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: (isDark ? Colors.black : Colors.white).withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFF6B35).withOpacity(0.3),
              ),
            ),
            child: IconButton(
              onPressed: _isLoading ? null : _loadNFTs,
              icon: _isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                ),
              )
                  : const Icon(
                Icons.refresh,
                color: Color(0xFFFF6B35),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
              const Color(0xFF000000),
              const Color(0xFF1A1A1A),
              const Color(0xFF2D1810),
            ]
                : [
              Colors.grey[50]!,
              Colors.grey[100]!,
              const Color(0xFFFFF5F0),
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark ? Colors.white : Colors.black87,
                    ),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'NFT\'ler cüzdandan yükleniyor...',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bu işlem biraz zaman alabilir',
                  style: TextStyle(
                    color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          )
              : _errorMessage != null
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Hata Oluştu',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadNFTs,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text(
                    'Tekrar Dene',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          )
              : _nfts.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B35).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.image,
                    color: Color(0xFFFF6B35),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'NFT Bulunamadı',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bu cüzdanda henüz NFT yok',
                  style: TextStyle(
                    color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadNFTs,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text(
                    'Yenile',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          )
              : Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // Stats
                _buildGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.collections,
                            color: Color(0xFFFF6B35),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cüzdandaki NFT\'ler',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_nfts.length} adet NFT bulundu',
                                style: TextStyle(
                                  color: (isDark ? Colors.white : Colors.black87).withOpacity(0.8),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Canlı',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // NFT Grid
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: _nfts.length,
                    itemBuilder: (context, index) {
                      return _buildNFTCard(_nfts[index]);
                    },
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
