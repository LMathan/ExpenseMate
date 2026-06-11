class GroupModel {
  final String id;
  final String name;
  final List<String> memberNames;
  final List<String> memberEmails;
  final List<String> memberUids;
  final String createdBy;

  GroupModel({
    required this.id,
    required this.name,
    required this.memberNames,
    required this.memberEmails,
    required this.memberUids,
    required this.createdBy,
  });

  factory GroupModel.fromMap(Map<dynamic, dynamic> map) {
    return GroupModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      memberNames: List<String>.from(map['memberNames'] ?? []),
      memberEmails: List<String>.from(map['memberEmails'] ?? []),
      memberUids: List<String>.from(map['memberUids'] ?? []),
      createdBy: map['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'memberNames': memberNames,
      'memberEmails': memberEmails,
      'memberUids': memberUids,
      'createdBy': createdBy,
    };
  }
}
