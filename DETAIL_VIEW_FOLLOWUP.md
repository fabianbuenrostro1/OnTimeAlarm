# Detail View Follow-Up Tasks

## Current State (as of commit 9d80cc1)
The full-screen immersive layout is implemented with:
- Full-bleed map extending under nav bar
- Floating white card with rounded top corners
- Toggle moved to card header
- "Open in Maps" button at card bottom

## Issues to Fix

### 1. Traffic Badge Position
**Problem:** "Traffic Clear" badge is positioned too low on the map, getting lost in the content area.

**File:** `OnTimeAlarm/Views/DepartureDetailView.swift` (lines ~112-124)

**Current code:**
```swift
.padding(.top, geometry.safeAreaInsets.top + 50)
.padding(.leading, 12)
```

**Fix:** Move traffic badge to top-right corner of map, below the nav bar but clearly visible:
```swift
// Change alignment from .topLeading to .topTrailing or .top
// Reduce the top padding offset
.padding(.top, geometry.safeAreaInsets.top + 8)
.padding(.trailing, 12)  // or keep .leading, just reduce top offset
```

### 2. Edit Button Visibility
**Problem:** White pencil icon (`pencil.circle.fill`) is hard to see against the map.

**File:** `OnTimeAlarm/Views/DepartureDetailView.swift` (lines ~236-246)

**Current code:**
```swift
Image(systemName: "pencil.circle.fill")
    .font(.title3)
    .symbolRenderingMode(.hierarchical)
    .foregroundStyle(.white)
```

**Fix options:**
1. Add a material background behind the button:
```swift
Button {
    showingEditor = true
} label: {
    Image(systemName: "pencil.circle.fill")
        .font(.title2)
        .foregroundStyle(.primary)
}
.padding(8)
.background(.regularMaterial, in: Circle())
```

2. Or use a filled style with contrast:
```swift
Image(systemName: "pencil.circle.fill")
    .font(.title2)
    .symbolRenderingMode(.palette)
    .foregroundStyle(.white, .black.opacity(0.3))
```

### 3. "Open in Maps" Button Not Visible
**Problem:** The CTA button at the bottom of the card is cut off / below the fold on initial load.

**File:** `OnTimeAlarm/Views/DepartureDetailView.swift`

**Root cause:** The card spacer height (`geometry.size.height * 0.35`) pushes content too far down.

**Fix options:**

**Option A - Reduce map/spacer height:**
```swift
// Change from 0.35 to 0.28 or less
Color.clear.frame(height: geometry.size.height * 0.28)

// Also reduce map height from 0.42 to 0.35
.frame(height: geometry.size.height * 0.35)
```

**Option B - Make the card overlap the map more:**
```swift
// Use negative offset on the card
Color.clear.frame(height: geometry.size.height * 0.30)
```

**Option C - Add bottom safe area padding to ensure button is visible:**
```swift
.padding(.bottom, 24)  // Already exists, may need to increase
.padding(.bottom, geometry.safeAreaInsets.bottom + 24)
```

## Recommended Implementation Order
1. Fix traffic badge position (quick win)
2. Fix edit button visibility (add material background)
3. Adjust card position so CTA is visible on load

## Testing Checklist
- [ ] Traffic badge visible and not overlapping card
- [ ] Edit button clearly visible against map
- [ ] "Open in Maps" button visible without scrolling
- [ ] Card still overlaps map nicely (visual depth)
- [ ] Scrolling still works smoothly
- [ ] All content accessible

## Files to Modify
- `OnTimeAlarm/Views/DepartureDetailView.swift`

## Context for Next Session
The user wants a premium, Apple Maps-style detail view. Key design goals:
- Full-bleed map hero
- Floating card sheet pattern
- Toggle accessible at top of card (not buried)
- All critical actions visible on initial load
- Professional, polished appearance

Reference: iOS 26 Liquid Glass patterns, Apple Maps place cards
