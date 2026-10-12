local layout = assert(loadstring(__GRIMOIRE_HOME_LAYOUT_SOURCE))()

for _, size in { { 780, 336 }, { 976, 747 }, { 736, 459 } } do
	local width, height = size[1], size[2]
	local page = layout.compute(width, height)
	assert(page.TwoPages, "Wide notebook must use both pages")
	assert(page.GridSize == page.Cell * 3 + 16, "Nine slots must form exactly three columns")
	assert(page.SlotsX >= 0 and page.SlotsX + page.GridSize <= width / 2, "Slots must fit the left page")
	assert(page.SlotsY >= 0 and page.SlotsY + page.GridSize <= height, "Slots must fit page height")
	assert(page.CreateX >= width / 2 and page.CreateX + page.CreateSize <= width, "Create tile must fit the right page")
	assert(page.CreateY >= 0 and page.CreateY + page.CreateSize <= height, "Create tile must fit page height")
	assert(page.CreateSize >= page.Cell * 2, "Create tile should be a prominent action")
end

local shortBook = layout.compute(780, 336)
assert(shortBook.Cell >= 100, "Short landscape notebook should still have large slots")
local mobile = layout.compute(328, 496)
assert(not mobile.TwoPages and mobile.CreateY < mobile.SlotsY, "Narrow notebook stacks create above slots")
assert(mobile.CanvasHeight >= mobile.SlotsY + mobile.GridSize, "Stacked slots remain reachable by scrolling")
print("PASS: grimoire first spread centers three-by-three slots and a large Create tile")
