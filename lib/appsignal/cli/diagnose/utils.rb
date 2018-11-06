module Appsignal
  class CLI
    class Diagnose
      class Utils
        def self.username_for_uid(uid)
          passwd_struct = Etc.getpwuid(uid)
          return unless passwd_struct
          passwd_struct.name
        end

        def self.group_for_gid(gid)
          passwd_struct = Etc.getgrgid(gid)
          return unless passwd_struct
          passwd_struct.name
        end
      end
    end
  end
end
