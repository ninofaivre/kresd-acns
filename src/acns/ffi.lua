local ffi = require("ffi")

ffi.cdef[[
typedef unsigned int uid_t;
typedef unsigned int gid_t;
int chown(const char *pathname, uid_t owner, gid_t group);
typedef unsigned int mode_t;
int chmod(const char *pathname, mode_t mode);
struct group {
  char *gr_name;
  char *gr_passwd;
  gid_t gr_gid;
  char **gr_mem;
};
struct group  *getgrnam(const char *);
int unlink(const char *pathname);
]]
