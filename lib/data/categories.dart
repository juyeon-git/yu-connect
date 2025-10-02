// GENERATED from 카테고리.txt
// Do not edit by hand. Update 카테고리.txt and re-generate if needed.
library categories;

/// 대분류(앱/관리자 공통).
const kMajors = ['시설', '학사'];

/// 시설 구역(A~G).
const kZones = ['A','B','C','D','E','F','G'];

/// 구역별 건물 목록(코드/이름).
const kBuildingsByZone = <String, List<Map<String, String>>>{
  'A': [
    {'code': 'A01', 'name': '천마지문'},
    {'code': 'A02', 'name': '국제교류센터'},
    {'code': 'A04', 'name': '박물관'},
    {'code': 'A05', 'name': '학생지원센터'},
    {'code': 'A06', 'name': '예술대학 디자인관'},
    {'code': 'A07', 'name': '예술대학 미술관'},
    {'code': 'A08', 'name': '사범대학'},
    {'code': 'A09', 'name': '중앙테니스장'},
    {'code': 'A10', 'name': '예술대학 음악관'},
    {'code': 'A11', 'name': '예술대학 심포니홀'},
    {'code': 'A12', 'name': '시설관리지원센터'},
    {'code': 'A13', 'name': '필승관'},
    {'code': 'A14', 'name': '씨름장'},
    {'code': 'A16', 'name': '벤처창업관'},
    {'code': 'A17', 'name': 'Y-STAR 경산 청년창의창작소'},
    {'code': 'A24', 'name': '예술대학 세라믹 실기동'},
    {'code': 'A25', 'name': '태권도장'},
    {'code': 'A27', 'name': '탁구장'},
    {'code': 'A29', 'name': '독도자연생태온실'},
  ],
  'B': [
    {'code': 'B01', 'name': '노천강당'},
    {'code': 'B02', 'name': '상경관'},
    {'code': 'B03', 'name': '인문관'},
    {'code': 'B04', 'name': '중앙도서관'},
    {'code': 'B05', 'name': '사회과학관'},
    {'code': 'B06', 'name': '학생회관'},
    {'code': 'B07', 'name': '이희건기념관'},
  ],
  'C': [
    {'code': 'C01', 'name': '본부본관'},
    {'code': 'C02', 'name': '외국어교육원'},
    {'code': 'C03', 'name': '천마관'},
    {'code': 'C04', 'name': 'AI스마트교육센터'},
    {'code': 'C06', 'name': '야구부실내연습장'},
    {'code': 'C07', 'name': '승리관'},
    {'code': 'C21', 'name': '학사민원실'},
    {'code': 'C22', 'name': '종합강의동'},
    {'code': 'C23', 'name': '국제교류본관'},
    {'code': 'C24', 'name': '국제교류별관'},
    {'code': 'C25', 'name': '동문회관'},
    {'code': 'C26', 'name': '우체국'},
    {'code': 'C31', 'name': '교직원테니스장'},
  ],
  'D': [
    {'code': 'D01', 'name': '생활관A동'},
    {'code': 'D02', 'name': '생활관B동'},
    {'code': 'D03', 'name': '생활관C동'},
    {'code': 'D04', 'name': '생활관D동'},
    {'code': 'D05', 'name': '생활관E동'},
    {'code': 'D06', 'name': '생활관F동'},
    {'code': 'D07', 'name': '생활관G동'},
    {'code': 'D08', 'name': '생활관H동'},
    {'code': 'D09', 'name': '생활관식당'},
    {'code': 'D10', 'name': '고시원'},
    {'code': 'D21', 'name': '생활관(향토관,기독생활관)'},
  ],
  'E': [
    {'code': 'E02', 'name': '천마아트센터'},
    {'code': 'E04', 'name': '체조장'},
    {'code': 'E05', 'name': '천마체육관'},
    {'code': 'E21', 'name': 'IT관'},
    {'code': 'E22', 'name': '전기관'},
    {'code': 'E23', 'name': '섬유관'},
    {'code': 'E24', 'name': '화공관'},
    {'code': 'E26', 'name': '수리실험동'},
    {'code': 'E28', 'name': '소재관'},
    {'code': 'E29', 'name': '기계관'},
  ],
  'F': [
    {'code': 'F03', 'name': '건축관'},
    {'code': 'F04', 'name': '정보전산원'},
    {'code': 'F05', 'name': '공과대학강당'},
    {'code': 'F06', 'name': '정보통신연구소'},
    {'code': 'F07', 'name': '건설관'},
    {'code': 'F21', 'name': '제1과학관'},
    {'code': 'F22', 'name': '제2과학관'},
    {'code': 'F23', 'name': '제3과학관'},
    {'code': 'F24', 'name': '과학도서관'},
    {'code': 'F25', 'name': '자연계식당'},
    {'code': 'F26', 'name': '생명응용과학대 제1실험동'},
    {'code': 'F27', 'name': '생명응용과학대본관'},
    {'code': 'F28', 'name': '생명응용과학대제2실험동'},
    {'code': 'F29', 'name': '생명응용과학대제3실험동'},
  ],
  'G': [
    {'code': 'G01', 'name': '생활과학대학본관'},
    {'code': 'G02', 'name': '생활과학대학별관'},
    {'code': 'G03', 'name': '법학전문도서관'},
    {'code': 'G04', 'name': '대학원/법학전문대학원'},
    {'code': 'G07', 'name': '약학관'},
    {'code': 'G11', 'name': 'CRC'},
    {'code': 'G12', 'name': '창업보육센터'},
    {'code': 'G13', 'name': '로봇관'},
    {'code': 'G14', 'name': '중앙기기센터'},
    {'code': 'G15', 'name': '생산기술연구원'},
    {'code': 'G16', 'name': '자동차관'},
    {'code': 'G17', 'name': '풍동실험실'},
    {'code': 'G18', 'name': '제2공장형실습장'},
    {'code': 'G19', 'name': '안전교육체험장'},
    {'code': 'G41', 'name': '구계서원'},
    {'code': 'G42', 'name': '까치구멍집'},
    {'code': 'G43', 'name': '의인정사'},
    {'code': 'G45', 'name': '민속촌해우소'},
    {'code': 'G46', 'name': '화산서당'},
    {'code': 'G47', 'name': '경주맞배집'},
    {'code': 'G48', 'name': '일휴당'},
    {'code': 'G49', 'name': '쌍송정'},
  ],
};

/// 예: 'B04' -> 'B04 중앙도서관'
String buildingDisplay(String code) {
  if (code.isEmpty) return code;
  final zone = code[0];
  final list = kBuildingsByZone[zone];
  if (list == null) return code;
  final idx = list.indexWhere((e) => e['code'] == code);
  if (idx == -1) return code;
  final name = list[idx]['name']!;
  return '$code $name';
}

/// 예: 'B04' -> 'B'
String? zoneOf(String? buildingCode) {
  if (buildingCode == null || buildingCode.isEmpty) return null;
  return buildingCode[0];
}
