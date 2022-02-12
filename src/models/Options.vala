/*
 * This file is part of musectory-player.
 *
 *     musectory-player is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     musectory-player is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with musectory-player.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Copyright 2018 Takayuki Tanaka
 */

namespace Musectory {
    public class Options {
        private Gee.Map<Musectory.OptionKey, Gee.List<string> > config_map;

        public Options() {
            config_map = new Gee.HashMap<Musectory.OptionKey, Gee.List<string> >();
            {
                foreach (OptionKey key in OptionKey.values()) {
                    config_map.set(key, new Gee.ArrayList<string>());
                }
                string home_dir = Environment.get_home_dir();
                string config_dir = @"$(home_dir)/.$(PROGRAM_NAME)";
                string css_path = @"$(config_dir)/$(PROGRAM_NAME).css";
                config_map.get(OptionKey.CONFIG_DIR).add(config_dir);
                config_map.get(OptionKey.CSS_PATH).add(css_path);
                config_map.get(OptionKey.LAST_VISITED_DIR).add(@"$(home_dir)/Music");
                config_map.get(OptionKey.FINDER_ICON_SIZE).add(128.to_string());
                config_map.get(OptionKey.PLAYLIST_THUMBNAIL_SIZE).add(48.to_string());
                config_map.get(OptionKey.CONTROLLER_IMAGE_SIZE_MIN).add(64.to_string());
                config_map.get(OptionKey.CONTROLLER_IMAGE_SIZE_MAX).add(127.to_string());
            }
        }

        public string? get(OptionKey key) {
            if (config_map.get(key).size > 0) {
                return config_map.get(key).last();
            } else {
                return null;
            }
        }

        public Gee.List<string> get_all(OptionKey key) {
            return config_map.get(key);
        }

        public void remove_key(OptionKey key) {
            config_map.get(key).clear();
        }

        public void set(OptionKey key, string? value) {
            if (value == null) {
                debug("WARNING: Options.set requires arg value is not null");
                return;
            }
            if (!config_map.has_key(key)) {
                config_map.set(key, new Gee.ArrayList<string>());
            }
            config_map.get(key).add(value);
        }

        public Gee.Set<OptionKey> keys() {
            return config_map.keys;
        }

        public void parse_args(ref unowned string[] args) throws Musectory.Error {
            for (int i = 1; i < args.length; i++) {
                OptionKey key;
                try {
                    key = OptionKey.value_of(args[i]);
                } catch (Musectory.Error e) {
                    stderr.printf(@"MusectoryError: $(e.message) that is $(args[i])\n");
                    continue;
                }
                switch (key) {
                  case Musectory.OptionKey.CSS_PATH:
                  case Musectory.OptionKey.CONFIG_DIR:
                    File option_file = File.new_for_path(args[i + 1]);
                    if (option_file.query_exists()) {
                        config_map.get(key).add(option_file.get_path());
                        i++;
                    } else {
                        throw new Musectory.Error.FILE_DOES_NOT_EXISTS(_("File does not exists (%s)\n").printf(option_file.get_path()));
                    }
                    break;
                default:
                    string value = args[i + 1];
                    config_map.get(key).add(value);
                    i++;
                    break;
                }
            }
        }

        public void parse_conf() throws Musectory.Error {
            try {
                string? config_dir = config_map.get(OptionKey.CONFIG_DIR).last();
                string config_file_path = config_dir + "/" + Musectory.PROGRAM_NAME + ".conf";
                File config_file = File.new_for_path(config_file_path);
                DataInputStream dis = new DataInputStream(config_file.read());
                string? line = null;
                while ((line = dis.read_line()) != null) {
                    int pos_eq = line.index_of_char('=');
                    string key = line.substring(0, pos_eq);
                    string option_value = line.substring(pos_eq + 1);
                    debug(@"config key = $(key), value = $(option_value)");
                    Musectory.OptionKey option_key;
                    try {
                        option_key = OptionKey.value_of(key);
                    } catch (Musectory.Error e) {
                        stderr.printf(@"MusectoryError: $(e.message)\n");
                        continue;
                    }
                    switch (option_key) {
                      case Musectory.OptionKey.CSS_PATH:
                      case Musectory.OptionKey.CONFIG_DIR:
                        File option_file = File.new_for_path(option_value);
                        if (option_file.query_exists()) {
                            config_map.get(option_key).add(option_file.get_path());
                        } else {
                            throw new Musectory.Error.FILE_DOES_NOT_EXISTS(_("File does not exists (%s)\n").printf(option_file.get_path()));
                        }
                        break;
                    default:
                        config_map.get(option_key).add(option_value);
                        break;
                    }
                }
            } catch (Musectory.Error e) {
                stderr.printf(@"MusectoryError: $(e.message)\n");
                throw e;
            } catch (GLib.IOError e) {
                stderr.printf(@"IOError: $(e.message)\n");
            } catch (GLib.Error e) {
                stderr.printf(@"GLibError: $(e.message)\n");
            }
        }
    }
}
