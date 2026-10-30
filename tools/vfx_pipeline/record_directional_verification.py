"""Record observed Studio playback evidence, preserving the failed preload result."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BUNDLE = ROOT / "assets/vfx/generated/painted_fire_v1"


def payload(filename):
    receipt = json.loads((BUNDLE / filename).read_text(encoding="utf-8"))
    assert not receipt.get("isError"), filename
    return json.loads(next(b["text"] for b in receipt["content"] if b["type"] == "text"))


def main():
    publication = json.loads((BUNDLE / "published_assets.json").read_text())
    playback = payload("studio_playback_verify_receipt.json")
    assert playback["IsClient"] is True
    assert playback["After"]["FrameUpdates"] > playback["Before"]["FrameUpdates"]
    assert playback["After"]["CompletedLoops"] > playback["Before"]["CompletedLoops"]
    assert playback["After"]["LoadedImages"] == 4
    images = {entry["Image"]: entry for entry in playback["Images"]}
    preload = {entry["Content"]: entry["Status"] for entry in payload("studio_fetch_receipt.json")["Statuses"]}
    for entry in publication["assets"].values():
        assert images[entry["id"]]["IsLoaded"] is True
        entry.update(fetch_status="loaded_in_image_label", preload_status=preload[entry["id"]],
                     studio_visual_verified=True, verification_scope="Client ScreenGui playback review, not projectile integration")
    publication.update(status="uploaded_studio_playback_verified", runtime_integrated=False,
        verification={"date":"2026-10-17", "place_id":playback["PlaceId"],
            "receipt":"studio_playback_verify_receipt.json",
            "capture":"assets/vfx/previews/studio_directional_playback_0.jpg",
            "fps":8, "before":playback["Before"], "after":playback["After"],
            "note":"Raw-string PreloadAsync callbacks failed; actual ImageLabels loaded and animated successfully."})
    (BUNDLE / "published_assets.json").write_text(json.dumps(publication, indent=2)+"\n", encoding="utf-8")
    print("Recorded four loaded images, advancing frames, completed loops, and captured Studio review. Runtime integration remains pending.")


if __name__ == "__main__":
    main()
