import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

void main() {
  runApp(NoteApp());
}

class NoteApp extends StatefulWidget {
  @override
  _NoteAppState createState() => _NoteAppState();
}

class _NoteAppState extends State<NoteApp> {
  bool darkThemeEnabled = false;

  void toggleTheme() {
    setState(() {
      darkThemeEnabled = !darkThemeEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Заметки',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: darkThemeEnabled ? Brightness.dark : Brightness.light,
      ),
      home: NoteList(
        darkThemeEnabled: darkThemeEnabled,
        toggleTheme: toggleTheme,
      ),
    );
  }
}

class NoteList extends StatefulWidget {
  final bool darkThemeEnabled;
  final Function toggleTheme;

  NoteList({required this.darkThemeEnabled, required this.toggleTheme});

  @override
  _NoteListState createState() => _NoteListState();
}

enum SortBy { Title, CreatedDate, ModifiedDate }

class _NoteListState extends State<NoteList> {
  SortBy _sortBy = SortBy.Title;
  List<Note> notes = [];
  List<Folder> folders = [];
  Folder? currentFolder;
  bool isSelectionMode = false;
  List<Note> selectedNotes = [];

  Future<void> _loadNotes() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/notes.txt');
      if (await file.exists()) {
        final encodedNotes = await file.readAsString();
        final noteLines = encodedNotes.split('\n\r');
        notes = noteLines.map((line) {
          final parts = line.split('|').map((part) => part.replaceAll('\\n', '\n')).toList();
          return Note(
            title: parts[0],
            content: parts[1],
            folder: parts[2],
          );
        }).toList();
      }
    } catch (e) {
      print('Ошибка при загрузке заметок: $e');
    }
  }

  Future<void> _saveNotes() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/notes.txt');
      final encodedNotes = notes.map((note) => '${note.title}|${note.content.replaceAll('\n', '\\n')}|${note.folder}').join('\n\r');
      await file.writeAsString(encodedNotes);
    } catch (e) {
      print('Ошибка при сохранении заметок: $e');
    }
  }

  Future<void> _saveFolders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> folderNames = folders.map((folder) => folder.name).toList();
    await prefs.setStringList('folders', folderNames);
  }

  Future<void> _loadFolders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? folderNames = prefs.getStringList('folders');
    if (folderNames != null) {
      setState(() {
        folders = folderNames.map((name) => Folder(name: name)).toList();
      });
    }
  }

  void _showSortOptionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Сортировка заметок'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('По названию'),
                leading: Radio(
                  value: SortBy.Title,
                  groupValue: _sortBy,
                  onChanged: (SortBy? value) {
                    setState(() {
                      _sortBy = value!;
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ),
              ListTile(
                title: Text('По дате создания'),
                leading: Radio(
                  value: SortBy.CreatedDate,
                  groupValue: _sortBy,
                  onChanged: (SortBy? value) {
                    setState(() {
                      _sortBy = value!;
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ),
              ListTile(
                title: Text('По дате изменения'),
                leading: Radio(
                  value: SortBy.ModifiedDate,
                  groupValue: _sortBy,
                  onChanged: (SortBy? value) {
                    setState(() {
                      _sortBy = value!;
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _addNoteDialog(BuildContext context) {
    Note newNote = Note();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Новая заметка'),
          content: TextField(
            onChanged: (value) {
              newNote.title = value;
            },
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Отмена'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Сохранить'),
              onPressed: () {
                setState(() {
                  if (currentFolder != null) {
                    newNote.folder = currentFolder!.name;
                  }
                  notes.add(newNote);
                  _saveNotes();
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _addFolderDialog(BuildContext context) {
    Folder newFolder = Folder();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async {
            return false;
          },
          child: AlertDialog(
            title: Text('Новая папка'),
            content: TextField(
              onChanged: (value) {
                newFolder.name = value;
              },
            ),
            actions: <Widget>[
              TextButton(
                child: Text('Отмена'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text('Создать'),
                onPressed: () {
                  setState(() {
                    folders.add(newFolder);
                  });
                  _saveFolders();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _openFolder(Folder folder) {
    setState(() {
      currentFolder = folder;
    });
  }

  void _renameFolderDialog(BuildContext context, Folder folder) {
    String newName = folder.name;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Переименовать папку'),
          content: TextField(
            onChanged: (value) {
              newName = value;
            },
            controller: TextEditingController(text: newName),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Отмена'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Сохранить'),
              onPressed: () {
                setState(() {
                  var oldFolderName = folder.name;
                  folder.renameFolder(newName);
                  for (var note in notes) {
                    if (note.folder == oldFolderName) {
                      note.folder = newName;
                    }
                  }
                });
                _saveNotes();
                _saveFolders();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _deleteFolderDialog(BuildContext context, Folder folder) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Удалить папку'),
          content: Text(
              'Вы уверены, что хотите удалить папку "${folder.name}"? Все заметки внутри папки также будут удалены.'),
          actions: <Widget>[
            TextButton(
              child: Text('Отмена'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Удалить'),
              onPressed: () {
                setState(() {
                  folders.remove(folder);
                  notes.removeWhere((note) => note.folder == folder.name);
                  if (currentFolder == folder) {
                    currentFolder = null;
                  }
                  _saveNotes();
                  _saveFolders();
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  List<Note> getNotesInCurrentFolder() {
    List<Note> sortedNotes;

    if (currentFolder != null) {
      sortedNotes = notes.where((note) => note.folder == currentFolder!.name).toList();
    } else {
      sortedNotes = notes;
    }

    switch (_sortBy) {
      case SortBy.Title:
        sortedNotes.sort((a, b) => a.title.compareTo(b.title));
        break;
      case SortBy.CreatedDate:
        sortedNotes.sort((a, b) => a.createdDate.compareTo(b.createdDate));
        break;
      case SortBy.ModifiedDate:
        sortedNotes.sort((a, b) => a.modifiedDate.compareTo(b.modifiedDate));
        break;
    }

    return sortedNotes;
  }

  String getAppBarTitle() {
    if (currentFolder != null) {
      return currentFolder!.name;
    } else {
      return 'Все заметки';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _loadFolders();
  }
  @override
  void dispose() {
    selectedNotes.clear();
    isSelectionMode = false;
    super.dispose();
  }
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(getAppBarTitle()),
        actions: <Widget>[
          IconButton(
            icon: Icon(widget.darkThemeEnabled ? Icons.wb_sunny : Icons.nightlight_round),
            onPressed: () {
              widget.toggleTheme();
            },
          ),
          IconButton(
            icon: Icon(Icons.sort),
            onPressed: () {
              _showSortOptionsDialog(context);
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: Text(
                'Меню',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.list),
              title: Text('Все заметки'),
              onTap: () {
                setState(() {
                  currentFolder = null;
                });
                Navigator.pop(context);
              },
            ),
            for (var folder in folders)
              ListTile(
                leading: Icon(Icons.folder),
                title: Text(folder.name),
                onTap: () {
                  _openFolder(folder);
                  Navigator.pop(context);
                },
                onLongPress: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('Папка: ${folder.name}'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: Icon(Icons.edit),
                              title: Text('Переименовать'),
                              onTap: () {
                                Navigator.pop(context);
                                _renameFolderDialog(context, folder);
                              },
                            ),
                            ListTile(
                              leading: Icon(Icons.delete),
                              title: Text('Удалить'),
                              onTap: () {
                                Navigator.pop(context);
                                _deleteFolderDialog(context, folder);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ListTile(
              leading: Icon(Icons.create_new_folder),
              title: Text('Создать папку'),
              onTap: () {
                _addFolderDialog(context);
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.close),
              title: Text('Закрыть'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: ListView.builder(
        itemCount: getNotesInCurrentFolder().length,
        itemBuilder: (context, index) {
          final note = getNotesInCurrentFolder()[index];
          final isSelected = selectedNotes.contains(note);
          return ListTile(
              leading: isSelectionMode ? Checkbox (
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (isSelected) {
                      selectedNotes.remove(note);
                    } else {
                      selectedNotes.add(note);
                    }
                  });
                },
              ) : Icon(Icons.description),
              title: Text (
                note.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                note.content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                if (isSelectionMode) {
                  setState(() {
                    if (isSelected) {
                      selectedNotes.remove(note);
                    } else {
                      selectedNotes.add(note);
                    }
                  });
                } else {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => NoteDetail(
                              note: note,
                              updateNote: (updatedNote) {
                                setState(() {
                                  note.title = updatedNote.title;
                                  note.content = updatedNote.content;
                                });
                                _saveNotes();
                              }
                          )
                      )
                  );
                }
              },
              onLongPress: () {
                if (!isSelectionMode) {
                  setState(() {
                    isSelectionMode = true;
                    selectedNotes.add(note);
                  });
                }
              }
          );
        },
      ),
      floatingActionButton: isSelectionMode ? FloatingActionButton(
        onPressed: () {
          setState(() {
            notes.removeWhere((note) => selectedNotes.contains(note));
            selectedNotes.clear();
            isSelectionMode = false;
            _saveNotes();
          });
        },
        child: Icon(Icons.delete),
      ) : FloatingActionButton(
        onPressed: () {
          _addNoteDialog(context);
        },
        child: Icon(Icons.create),
      ),
    );
  }
}

class Note {
  String title = '';
  String content = '';
  String folder = '';
  DateTime createdDate = DateTime.now();
  DateTime modifiedDate = DateTime.now();

  Note({
    this.title = '',
    this.content = '',
    this.folder = '',
  });
}

class Folder {
  String name = '';

  void renameFolder(String newName) {
    name = newName;
  }

  Folder({
    this.name = '',
  });
}

class NoteDetail extends StatefulWidget {
  final Note note;
  final Function(Note) updateNote;

  NoteDetail({required this.note, required this.updateNote});

  @override
  _NoteDetailState createState() => _NoteDetailState();
}

class _NoteDetailState extends State<NoteDetail> {
  TextEditingController _titleController = TextEditingController();
  TextEditingController _contentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.note.title;
    _contentController.text = widget.note.content;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _titleController,
          onChanged: (value) {
            setState(() {
              widget.note.title = value;
              widget.updateNote(widget.note);
            });
          },
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: 'Заголовок',
          ),
          style: TextStyle(fontSize: 20),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: TextField(
          controller: _contentController,
          onChanged: (value) {
            setState(() {
              widget.note.content = value;
              widget.updateNote(widget.note);
            });
          },
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: 'Содержимое',
          ),
          maxLines: null,
        ),
      ),
    );
  }
}