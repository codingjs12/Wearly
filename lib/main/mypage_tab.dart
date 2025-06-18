import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:w2wproject/main/widget/settings_page.dart';
import 'package:w2wproject/main/widget/user_edit_page.dart';
import 'detail_page.dart';
import 'package:intl/intl.dart';

class MyPageTab extends StatefulWidget {
  final String? userId;

  const MyPageTab({Key? key, this.userId, required Function onUserTap}) : super(key: key);

  @override
  State<MyPageTab> createState() => _MyPageWidgetState();
}

Future<String?> getSavedUserId() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getString('userId');
}


class _MyPageWidgetState extends State<MyPageTab> {
  bool isExpanded = true;
  bool showDetail = false;
  String? selectedFeedId;
  bool isLoading = true;
  bool isUserLoading = true;

  String currentUserId = '';
  final FirebaseFirestore fs = FirebaseFirestore.instance;

  List<Map<String, dynamic>> userProfiles = [];
  Map<String, dynamic> mainCoordiFeed = {};

  final PageController _pageController = PageController(viewportFraction: 0.85);

  // 월별로 그룹화된 피드 아이템
  Map<String, List<Map<String, dynamic>>> feedItemsByMonth = {};

  Future<void> fetchFeeds() async {
    try {
      final snapshot = await fs.collection('feeds').orderBy('cdatetime', descending: true).get();
      final items = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;

        if (data['cdatetime'] is Timestamp) {
          DateTime date = (data['cdatetime'] as Timestamp).toDate();
          String monthKey = DateFormat('yyyy년 M월').format(date);

          feedItemsByMonth[monthKey] ??= [];
          feedItemsByMonth[monthKey]!.add(data);
        }

        return data;
      }).toList();

      // 최신 월부터 내림차순 정렬
      feedItemsByMonth = Map.fromEntries(
        feedItemsByMonth.entries.toList()
          ..sort((a, b) => b.key.compareTo(a.key)),
      );

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching feeds: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    fetchFeeds();
    _loadUserId();

  }

  Future<void> _loadUserId() async {
    String? userId = await getSavedUserId();
    setState(() {
      currentUserId = userId!;
      print("currentUserId====>$currentUserId");
      fetchCurrentUserProfile();
    });
  }

  Future<void> fetchCurrentUserProfile() async {
    if (currentUserId == null) return; // null 체크

    currentUserId = widget.userId ?? currentUserId;

    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        final userId = docSnapshot.id;
        data['id'] = userId;

        setState(() {
          userProfiles = [data];
          isUserLoading = false;
        });

        // 🔽 mainCoordiId 가져와서 feeds에서 문서 가져오기
        final mainCoordiId = data['mainCoordiId'];
        if (mainCoordiId != null && mainCoordiId.toString().trim().isNotEmpty) {
          try {
            final feedSnapshot = await FirebaseFirestore.instance
                .collection('feeds')
                .doc(mainCoordiId)
                .get();

            if (feedSnapshot.exists) {
              final feedData = feedSnapshot.data()!;
              feedData['id'] = feedSnapshot.id;

              // 🔽 리스트에 추가
              setState(() {
                mainCoordiFeed = feedData;
              });

              print('mainCoordiFeeds 리스트에 추가됨: $feedData');
            } else {
              print('해당 mainCoordiId 문서가 존재하지 않음');
            }
          } catch (e) {
            print('feeds 문서 가져오기 실패: $e');
          }
        }
      } else {
        print('해당 userId 문서가 존재하지 않습니다.');
        setState(() {
          userProfiles = [];
          isUserLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isUserLoading = false;
      });
      print('유저 프로필 불러오기 실패: $e');
    }
  }



  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void openDetail(String feedId) {
    setState(() {
      selectedFeedId = feedId;
      showDetail = true;
    });
  }


  void closeDetail() {
    setState(() {
      showDetail = false;
    });
  }

  Map<String, dynamic> getUserProfile(String userId) {
    return userProfiles.firstWhere(
          (profile) => profile['id'] == userId,
      orElse: () => userProfiles[0],
    );
  }

  void openSettingsPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
  }

  void openUserEditPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserEditPage(userId: currentUserId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    if (isUserLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (userProfiles.isEmpty) {
      return const Center(child: Text("프로필 데이터를 불러올 수 없습니다."));
    }

    final String viewedUserId = widget.userId ?? currentUserId;

    print("widget.userId ==>${widget.userId }");

    print("viewedUserId==>$viewedUserId");

    final bool isOwnPage = viewedUserId == currentUserId;

    final Map<String, dynamic> profile = getUserProfile(viewedUserId);

    //print("profile ==> $profile");
    final theme = Theme.of(context);
    final bottomNavTheme = theme.bottomNavigationBarTheme;
    final backgroundColor = theme.scaffoldBackgroundColor;
    final navBackgroundColor = bottomNavTheme.backgroundColor ?? theme.primaryColor;
    final selectedItemColor = bottomNavTheme.selectedItemColor ?? Colors.white;
    final unselectedItemColor = bottomNavTheme.unselectedItemColor ?? Colors.white70;
    final screenWidth = MediaQuery.of(context).size.width;




    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 프로필 UI
            AnimatedContainer(
              duration: Duration(milliseconds: 200),
              width: screenWidth,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: unselectedItemColor.withOpacity(0.95),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: navBackgroundColor, width: 7)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    offset: Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: showDetail
                        ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (profile["profileImage"] != null &&
                            profile["profileImage"].toString().isNotEmpty)
                          CircleAvatar(
                            radius: 24,
                            backgroundImage: NetworkImage(profile["profileImage"]),
                          ),
                        SizedBox(width: 12),
                        Text(
                          profile["nickname"] ?? '',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: selectedItemColor),
                        ),
                      ],
                    )
                        : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (profile["profileImage"] != null &&
                            profile["profileImage"].toString().isNotEmpty)
                          CircleAvatar(
                            radius: 32,
                            backgroundImage: NetworkImage(profile["profileImage"]),
                          ),
                        SizedBox(height: 8),
                        Text(
                          profile["nickname"] ?? '',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: selectedItemColor),
                        ),
                        buildExpandedFeedSection(
                          imageUrls: mainCoordiFeed["imageUrls"] ?? [],
                          profile: profile,
                          isExpanded: isExpanded,
                          selectedItemColor: selectedItemColor,
                          pageController: _pageController,
                        ),
                        TextButton(
                          onPressed: () => setState(() => isExpanded = !isExpanded),
                          child: Icon(
                            isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            size: 32,
                            color: selectedItemColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 8,
                    child: isOwnPage
                        ? Row(
                      children: [
                        _buildIconBtn('assets/common/person_edit.png', () {
                          openUserEditPage(context);
                        }),
                        _buildIconBtn(Icons.settings, () {
                          openSettingsPage(context);
                        }),
                      ],
                    )
                        : ElevatedButton(
                      onPressed: () {},
                      child: Text("팔로우"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink[200],
                        foregroundColor: Colors.white,
                        shape: StadiumBorder(),
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 피드 목록 영역
            Expanded(
              child: IndexedStack(
                index: showDetail ? 1 : 0,
                children: [
                  isLoading
                      ? Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                    child: Column(
                      children: feedItemsByMonth.entries.map((entry) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Text(
                                entry.key,
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: selectedItemColor),
                              ),
                            ),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              itemCount: entry.value.length,
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 0.8,
                              ),
                              itemBuilder: (context, index) {
                                final item = entry.value[index];
                                final imageUrl = item["imageUrls"] != null && item["imageUrls"].isNotEmpty
                                    ? item["imageUrls"][0]
                                    : '';

                                return GestureDetector(
                                  onTap: () => openDetail(item['id']),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.grey[300],
                                    ),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: imageUrl != ''
                                              ? Image.network(imageUrl, fit: BoxFit.cover)
                                              : Image.asset('assets/noimg.jpg', fit: BoxFit.cover),
                                        ),
                                        if ((item["feeling"]?.toString().isNotEmpty ?? false) ||
                                            (item["temperature"]?.toString().isNotEmpty ?? false))
                                          Positioned.fill(
                                            child: Padding(
                                              padding: EdgeInsets.all(6),
                                              child: Stack(
                                                children: [
                                                  if (item["temperature"]?.toString().isNotEmpty ?? false)
                                                    Positioned(
                                                      top: 0,
                                                      right: 0,
                                                      child: _buildOverlayText('${item["temperature"]}℃'),
                                                    ),
                                                  if (item["feeling"]?.toString().isNotEmpty ?? false)
                                                    Positioned(
                                                      bottom: 0,
                                                      left: 0,
                                                      child: _buildOverlayText(item["feeling"]),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  if (selectedFeedId != null)
                    DetailPage(
                      key: ValueKey(selectedFeedId),
                      feedId: selectedFeedId!,
                      currentUserId: currentUserId,
                      onBack: closeDetail,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    ;
  }


  Widget _buildOverlayText(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  Widget _buildIconBtn(dynamic icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        margin: EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          shape: BoxShape.circle,
        ),
        child: icon is String
            ? Padding(padding: EdgeInsets.all(4), child: Image.asset(icon, color: Colors.black))
            : Icon(icon, size: 20, color: Colors.black),
      ),
    );
  }
}

Widget buildExpandedFeedSection({
  required List<dynamic> imageUrls,
  required Map<String, dynamic> profile,
  required bool isExpanded,
  required Color selectedItemColor,
  required PageController pageController,
}) {
  return AnimatedCrossFade(
    duration: Duration(milliseconds: 300),
    crossFadeState: isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
    firstChild: Column(
      children: [
        SizedBox(height: 8),
        SizedBox(
          height: 360,
          child: PageView.builder(
            controller: pageController,
            itemCount: imageUrls.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrls[index],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(child: CircularProgressIndicator());
                    },
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 8),
        Text(profile["bio"] ?? '', style: TextStyle(color: selectedItemColor)),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: (profile["interest"] as List<dynamic>? ?? [])
              .take(3)
              .map((item) => Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              item.toString(),
              style: TextStyle(color: Colors.blue),
            ),
          ))
              .toList(),
        )
      ],
    ),
    secondChild: SizedBox.shrink(),
  );
}

