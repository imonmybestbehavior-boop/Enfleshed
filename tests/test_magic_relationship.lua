local relationships = assert(loadfile("src/shared/Modules/MagicRelationship.luau"))()

assert(relationships.classify(true, true, false, false) == "Self", "Self identity must take precedence")
assert(relationships.classify(false, true, true, true) == "Hostile", "Hostility must take precedence over alignment")
assert(relationships.classify(false, false, true, false) == "Ally")
assert(relationships.classify(false, false, false, true) == "Ally")
assert(relationships.classify(false, false, false, false) == "Neutral")

for _, relation in ipairs({ "Self", "Hostile", "Ally", "Neutral" }) do
	assert(relationships.matches(relation, "Any"))
	assert(relationships.matches(relation, relation))
	assert(not relationships.matches(relation, "Unknown"))
end
assert(relationships.matches("Neutral", nil))
assert(
	relationships.resolveAlignment("Ally", "Human") == "Human",
	"Owned ally dummies should inherit their owner's relationship alignment"
)
assert(relationships.resolveAlignment("Hostile", nil) == "Hostile")
assert(relationships.resolveAlignment(nil, nil) == nil)

print("Magic relationships: classification, precedence, and target filters passed")
