local Identity = require("../src/shared/Modules/MagicSpellIdentitySpec")
local norm, valid, repair = Identity.normalizeName, Identity.validateName, Identity.repairName

assert(Identity.MaxNameLength == 32)
assert(norm("  Fire   Bolt ") == "Fire Bolt", "whitespace is trimmed and collapsed")
assert(norm("Fire\nBolt\t!") == "Fire Bolt !", "control characters become spaces")
assert(norm("   ") == nil and norm("") == nil and norm(nil) == nil and norm(5) == nil, "empty or non-text has no name")
assert(norm(string.rep("a", 40)) == string.rep("a", 32), "names are cut to 32 characters")
assert(norm(string.rep("é", 40)) == string.rep("é", 32), "cutting counts characters, not bytes")
assert(utf8.len(norm(string.rep("é", 40)) :: string) == 32, "cut never splits a UTF-8 character")
assert(norm(string.rep("a", 31) .. " b") == string.rep("a", 31), "no trailing space after a cut")
assert(norm("bad\255utf8") == nil, "invalid UTF-8 is rejected")
assert(norm("Long spell name here", 7) == "Long sp", "custom limit for the (copy) suffix")

assert(valid("Fire Bolt"), "canonical names validate")
assert(not valid(" Fire Bolt"), "untrimmed names are rejected")
assert(not valid(string.rep("a", 33)), "33 characters is too long")
assert(valid(string.rep("é", 32)), "32 multibyte characters is allowed")
assert(not valid("a\tb") and not valid("") and not valid(nil), "control, empty and missing names are rejected")

assert(repair(string.rep("x", 48)) == string.rep("x", 32), "old 48-character names are repaired")
assert(repair("") == Identity.DefaultName and repair(nil) == Identity.DefaultName, "unusable names fall back")

print("Spell name rules: normalize, 32-character UTF-8 cap, validation and repair passed")
