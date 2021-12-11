/*
 * This file is part of moegi-player.
 *
 *     moegi-player is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     moegi-player is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with moegi-player.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Copyright 2018 Takayuki Tanaka
 */

namespace Moegi.Files {
    public bool mimetype_is_audio(string file_path) throws GLib.Error {
        File file = File.new_for_path(file_path);
        if (file.query_exists()) {
            return file.query_info("standard::*", 0).get_content_type().has_prefix("audio/");
        } else {
            return false;
        }
    }

    public Moegi.FileType get_file_type(string file_path) throws FileError {
        Moegi.FileType answer = Moegi.FileType.UNKNOWN;
        GLib.File dir_file = GLib.File.new_for_path(file_path);
        try {
            GLib.FileInfo file_info = dir_file.query_info("standard::*", 0);
            GLib.FileType file_type = file_info.get_file_type();
            if (file_type == GLib.FileType.REGULAR) {
                return Moegi.FileType.FILE;
            }

            if (file_type == GLib.FileType.DIRECTORY) {
                answer = Moegi.FileType.DIRECTORY;
                DirectoryReader dreader = new DirectoryReader(file_path);
                dreader.directory_found.connect((dir) => {
                    answer = Moegi.FileType.DIRECTORY;
                    return false;
                });
                dreader.file_found.connect((file) => {
                    try {
                        GLib.FileInfo finfo = file.query_info("standard::*", 0);
                        if (finfo.get_content_type().has_prefix("audio/")) {
                            answer = Moegi.FileType.DISC;
                            return false;
                        } else {
                            return true;
                        }
                    } catch (GLib.Error e) {
                        stderr.printf(@"Error: $(e.message)\n");
                        return true;
                    }
                });
                dreader.run();
            }
        } catch (GLib.Error e) {
            stderr.printf(@"GLib.Error: $(e.message)\n");
        }
        return answer;
    }

    public void find_dir_file_names(string dir_path,
            out Gee.List<string> dir_list, out Gee.List<string> file_list) {
        try {
            Gee.List<string> dir_list_local = new Gee.ArrayList<string>();
            Gee.List<string> file_list_local = new Gee.ArrayList<string>();
            if (FileUtils.test(dir_path, FileTest.IS_REGULAR)) {
                file_list_local.add(dir_path);
            } else {
                DirectoryReader dreader = new DirectoryReader(dir_path);
                dreader.directory_found.connect((dir) => {
                    dir_list_local.add(dir.get_path());
                    return true;
                });
                dreader.file_found.connect((file) => {
                    try {
                        GLib.FileInfo info = file.query_info("standard::*", 0);
                        if (info.get_content_type().has_prefix("audio/")) {
                            file_list_local.add(file.get_path());
                        }
                    } catch (GLib.Error e) {
                        stderr.printf(@"GLib.Error: $(e.message)\n");
                    }
                    return true;
                });
                dreader.run();
            }
            dir_list = (owned) dir_list_local;
            file_list = (owned) file_list_local;
        } catch (Moegi.Error e) {
            stderr.printf(@"Moegi.Error: $(e.message)\n");
            dir_list = new Gee.ArrayList<string>();
            file_list = new Gee.ArrayList<string>();
        } catch (GLib.Error e) {
            stderr.printf(@"GLib.Error: $(e.message)\n");
            dir_list = new Gee.ArrayList<string>();
            file_list = new Gee.ArrayList<string>();
        }
    }

    public void find_dir_files(
        string dir_path, out Gee.List<string> dir_list, out Gee.List<Moegi.FileInfo?> file_list
        ) throws Moegi.Error, FileError
    {
        FileInfoAdapter freader = new FileInfoAdapter();
        Gee.List<string> dir_list_local = new Gee.ArrayList<string>();
        Gee.List<Moegi.FileInfo?> file_list_local = new Gee.ArrayList<Moegi.FileInfo?>();
        if (FileUtils.test(dir_path, FileTest.IS_REGULAR)) {
            file_list_local.add(freader.read_metadata_from_path(dir_path));
        } else {
            DirectoryReader dreader = new DirectoryReader(dir_path);
            dreader.directory_found.connect((dir) => {
                dir_list_local.add(dir.get_basename());
                return true;
            });
            dreader.file_found.connect((file) => {
                try {
                    GLib.FileInfo fi = file.query_info("standard::*", 0);
                    string mime_type = fi.get_content_type();
                    if (mime_type.has_prefix("audio/")) {
                        Moegi.FileInfo? file_info = freader.read_metadata_from_path(file.get_path());
                        if (file_info != null && file_info.type == Moegi.FileType.MUSIC) {
                            file_list_local.add(file_info);
                        }
                    }
                } catch (GLib.Error e) {
                    stderr.printf(@"GLib.Error: $(e.message)\n");
                }
                return true;
            });
            dreader.run();
        }
        dir_list = (owned) dir_list_local;
        file_list = (owned) file_list_local;
    }

    public Gee.List<string> find_file_names_recursively(string dir_path) {
        Gee.List<string> dir_list;
        Gee.List<string> file_list;
        find_dir_file_names(dir_path, out dir_list, out file_list);
        foreach (string subdir_path in dir_list) {
            file_list.add_all(Files.find_file_names_recursively(subdir_path));
        }
        return file_list;
    }

    public Gee.List<Moegi.FileInfo?>? get_file_info_list_in_dir(string dir_path) {
        if (!GLib.FileUtils.test(dir_path, FileTest.IS_DIR)) {
            return null;
        }

        Gee.List<Moegi.FileInfo?> info_list = new Gee.ArrayList<Moegi.FileInfo?>();
        Gee.List<Moegi.FileInfo?> file_list = new Gee.ArrayList<Moegi.FileInfo?>();

        try {
            DirectoryReader dreader = new DirectoryReader(dir_path);
            dreader.directory_found.connect((directory) => {
                info_list.add(make_subdir_info(dir_path, directory.get_path()));
                return true;
            });
            dreader.file_found.connect((file) => {
                try {
                    GLib.FileInfo g_info = file.query_info("standard::*", 0);
                    if (g_info.get_content_type().has_prefix("audio/")) {
                        FileInfoAdapter freader = new FileInfoAdapter();
                        print(@"file_found $(file.get_path())\n");
                        Moegi.FileInfo? file_info = freader.read_metadata_from_path(file.get_path());
                        print(@"file info was found $(file.get_path())\n");
                        if (file_info != null) {
                            file_list.add(file_info);
                        }
                    }
                } catch (GLib.Error e) {
                    stderr.printf(@"GLib.Error: $(e.message)\n");
                }
                return true;
            });
            dreader.run();
            info_list.sort((a, b) => a.name.collate(b.name));
            file_list.sort((a, b) => a.name.collate(b.name));
            info_list.add_all(file_list);
        } catch (Moegi.Error e) {
            stderr.printf(@"Moegi.Error: $(e.message)\n");
        } catch (GLib.Error e) {
            stderr.printf(@"GLib.Error: $(e.message)\n");
        }
        return info_list;
    }

    public Gee.List<GLib.File> get_children(string dir_path) throws Moegi.Error, FileError {
        Gee.List<File> dir_list = new Gee.ArrayList<File>();
        Gee.List<File> file_list = new Gee.ArrayList<File>();
        DirectoryReader dreader = new DirectoryReader(dir_path);
        dreader.directory_found.connect((directory) => {
            dir_list.add(directory);
            return true;
        });
        dreader.file_found.connect((file) => {
            file_list.add(file);
            return true;
        });
        dreader.run();
        dir_list.sort((a, b) => a.get_basename().collate(b.get_basename()));
        file_list.sort((a, b) => a.get_basename().collate(b.get_basename()));
        Gee.List<File> result = new Gee.ArrayList<File>();
        result.add_all(dir_list);
        result.add_all(file_list);
        return result;
    }

    public Gee.List<Moegi.FileInfo?> find_file_infos_recursively(string dir_path) throws FileError {
        FileInfoAdapter freader = new FileInfoAdapter();
        Gee.List<Moegi.FileInfo?> info_list = new Gee.ArrayList<Moegi.FileInfo?>();
        if (!GLib.FileUtils.test(dir_path, FileTest.IS_DIR)) {
            Moegi.FileInfo? finfo = freader.read_metadata_from_path(dir_path);
            info_list.add(finfo);
        } else {
            var file_list = find_file_names_recursively(dir_path);
            debug("find_file_infos_recursively");
            foreach (string file_name in file_list) {
                debug("    file_name: %s", file_name);
                Moegi.FileInfo? finfo = freader.read_metadata_from_path(file_name);
                info_list.add(finfo);
            }
        }
        return info_list;
    }

    public Gdk.Pixbuf? load_first_artwork(string dir_path, int size)
            throws Moegi.Error, FileError {
        Gdk.Pixbuf? pixbuf = null;
        DirectoryReader dreader = new DirectoryReader(dir_path);
        FileInfoAdapter mreader = new FileInfoAdapter();
        dreader.file_found.connect((file) => {
            Moegi.FileInfo? file_info = mreader.read_metadata_from_path(file.get_path());
            if (file_info != null && file_info.artwork != null) {
                pixbuf = file_info.artwork;
                return false;
            }
            return true;
        });
        dreader.run();
        return pixbuf;
    }

    public string extension(string file_path) {
        return file_path.substring(file_path.last_index_of_char('.') + 1, file_path.length);
    }

    public string create_dir_artwork_path(string dir_path, string extension) {
        string dirname = Path.get_basename(Path.get_dirname(dir_path));
        string basename = Path.get_basename(dir_path);
        return "/tmp/" + PROGRAM_NAME + "/" + dirname + "_" + basename + (extension != "" ? "." + extension : "");
    }

    public bool contains_music(string dir_path, int max_depth = 0, int depth = 0)
            throws Moegi.Error, FileError {
        bool result = false;
        DirectoryReader dreader = new DirectoryReader(dir_path);
        dreader.file_found.connect((file) => {
            try {
                GLib.FileInfo file_info = file.query_info("standard::*", 0);
                if (file_info.get_content_type().has_prefix("audio/")) {
                    result = true;
                    return false;
                }
            } catch (GLib.Error e) {
                stderr.printf(@"Error: $(e.message)\n");
            }
            return true;
        });
        dreader.run();
        return result;
    }

    public Moegi.FileInfo make_subdir_info(string dir_path, string subdir_path) {
        Moegi.FileInfo info = new Moegi.FileInfo();
        info.dir = dir_path.dup();
        info.path = subdir_path.dup();
        info.name = Path.get_basename(subdir_path);
        info.type = Moegi.FileType.DIRECTORY;
        return info;
    }
}

