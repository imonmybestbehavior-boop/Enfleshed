"""Static contracts for the Grimoire authoring redesign."""
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
	return (ROOT / path).read_text()


class GrimoireRedesignContract(unittest.TestCase):
	@classmethod
	def setUpClass(cls) -> None:
		cls.ui = read("src/client/Controllers/MagicLabController.luau")
		cls.schema = read("src/shared/Configuration/MagicSchema.luau")
		cls.view = read("src/client/UI/Grimoire.luau")
		cls.theme = read("src/client/UI/GrimoireTheme.luau")
		cls.guide = read("src/shared/Modules/MagicAuthoringGuide.luau")
		cls.summary = read("src/shared/Modules/GrimoireSummary.luau")

	def test_creator_choices_hide_internal_authoring_contracts(self):
		self.assertNotRegex(
			self.ui,
			r"(?i)(?:select|heading|row|info|button)\s*\(\s*['\"][^'\"]*\b(?:source|principle|expression)\b",
		)
		self.assertIn("supportsPayloadCapability(kind, draft.Form, event)", self.ui)
		self.assertIn('local available = (capabilityCompatible and formAndTargetCompatible) or value ~= nil', self.ui)
		self.assertNotIn('Schema.supportsPayload(kind, draft.Form, event, draft.Source.Principle)', self.ui)
		self.assertNotIn('OptionsByPrinciple', self.ui)
		self.assertNotIn('selectedRequiredPrinciple', self.ui)
		self.assertIn('Schema.supportsPayloadCapability(kind, form, event)', self.schema)

	def test_creator_steps_use_parchment_choice_tiles(self):
		creator = self.ui[self.ui.index('if pageMode == "Create" then', self.ui.index('rebuild = function()')):
			self.ui.index('if pageMode == "Library" then', self.ui.index('rebuild = function()'))]
		self.assertEqual(creator.count('creationChoiceGrid(options)'), 3)
		self.assertNotIn('info(', creator)
		self.assertNotIn('row(', creator)
		self.assertIn('SpellVisual.render(icon, option.Preview, true)', self.ui)
		self.assertIn('face.Name = "ParchmentFace"', self.ui)
		self.assertIn('lip.Name = "RaisedEdge"', self.ui)

	def test_effect_selection_and_configuration_are_separate_in_both_modes(self):
		section_ids = re.findall(r'Id = "([A-Za-z]+)"', self.schema[: self.schema.index("Schema.Principles =")])
		self.assertEqual(
			section_ids,
			[
				"Setup",
				"Targeting",
				"Conditions",
				"ChooseEffects",
				"ConfigureEffects",
				"Casting",
				"Cost",
				"Presentation",
				"Test",
			],
		)
		self.assertIn('activeSection == "ChooseEffects" or activeSection == "ConfigureEffects"', self.ui)
		self.assertIn('local configuring = activeSection == "ConfigureEffects"', self.ui)
		self.assertIn('pageMode, activeSection = "Editor", "ConfigureEffects"', self.ui)
		self.assertIn('expandedGroups[currentGroup] == true', self.ui)

	def test_book_layout_keeps_navigation_summary_and_actions_in_stable_regions(self):
		self.assertIn('Instance.new("ScrollingFrame")', self.ui)
		self.assertIn("Enum.ScreenInsets.CoreUISafeInsets", self.ui)
		self.assertIn("gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling", self.ui)
		self.assertIn("notebook.ZIndex = 1", self.view)
		self.assertIn("child.ZIndex = 10", self.view)
		self.assertIn('overview.Name = "LiveSpellSummary"', self.view)
		self.assertIn('navigation.ScrollingEnabled = mode == "Editor"', self.view)
		self.assertIn("layoutFooterButtons()", self.ui)
		self.assertIn("scroll.CanvasPosition = previousCanvasPosition", self.ui)
		self.assertIn('local editorSpread = mode == "Editor" and width >= 680', self.view)
		self.assertIn('local editorTabs = { "BACK", "FORM", "TARGET", "RULES", "CHOOSE", "TUNE", "CAST", "COST", "LOOK", "TEST" }', self.view)
		self.assertIn('overview.Position = UDim2.fromOffset(pageWidth + 18, 88)', self.view)
		self.assertIn('editorPreview.Size = UDim2.new(1, -24, 1, -52)', self.ui)
		self.assertIn('cardPairHolder.Name = "ParchmentChoicePair"', self.ui)
		self.assertIn('frame.Name = "ParchmentChoice"', self.ui)
		self.assertIn('item.Size = UDim2.fromOffset(cell, cell)', read("src/client/UI/GrimoireLibraryView.luau"))

	def test_library_cards_turn_pages_without_vertical_scrolling(self):
		library = read("src/client/UI/GrimoireLibraryView.luau")
		self.assertIn('holder.Name = "LibrarySpread"', library)
		self.assertIn('LibraryLayout.compute(width, height, columns, #tiles)', library)
		self.assertIn('button.Name = if nextPage then "NextLibraryPage" else "PreviousLibraryPage"', library)
		self.assertIn('scroll.ScrollingEnabled = pageMode ~= "Library" or libraryView.Selected ~= nil', self.ui)
		self.assertIn('contentTop = if mode == "Slots" or mode == "Create" or mode == "Library"', self.view)

	def test_grimoire_uses_dark_ink_on_light_surfaces(self):
		self.assertIn("Page = Color3.fromRGB(247, 229, 197)", self.theme)
		self.assertIn("Ink = Color3.fromRGB(23, 32, 42)", self.theme)
		self.assertIn("Theme.Surface", self.ui)
		self.assertIn("Theme.Ink", self.ui)
		self.assertNotIn("Color3.fromRGB(107, 84, 58)", self.ui)

	def test_draft_library_equip_and_test_actions_remain_distinct(self):
		for phrase in ('action("SAVE DRAFT"', 'action("SAVE SPELL"', 'action("EQUIP"', '"TEST EQUIPPED"'):
			self.assertIn(phrase, self.ui)
		self.assertIn('ctx.editRecord(self.Selected, record.Definition)', read("src/client/UI/GrimoireLibraryView.luau"))
		self.assertIn('local Library = { Version = 2', read("src/shared/Modules/GrimoireLibrary.luau"))
		self.assertIn('raw.Version == Library.Version', read("src/server/Services/MagicLabService.luau"))
		self.assertIn('local valid, reason = Spec.validate(data.Definition)', read("src/server/Services/MagicLabService.luau"))

	def test_summaries_do_not_describe_internal_values(self):
		self.assertNotIn('"Source:', self.summary)
		self.assertNotIn('"Principle:', self.summary)
		self.assertNotIn('"Expression:', self.summary)
		self.assertIn("creatorIssue(reason)", self.summary)


if __name__ == "__main__":
	unittest.main()
