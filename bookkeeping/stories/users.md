# Users

Personas for DriftID — a car make/model identification app built from an uploaded image.

## Car enthusiast

**Who:** Someone curious about cars they see in photos, listings, or social media.

**Goals:**
- Upload or paste a car photo and get a make/model guess quickly
- See how confident the system is, including alternative matches when unsure
- Use the app without installing Python or understanding ML

**Pain points:**
- Fine-grained models look alike; a single label with no alternatives feels unreliable
- Poor photo quality (angle, crop, lighting) makes results hard to trust without context

---

## Used-car shopper

**Who:** A buyer browsing listings who wants a quick sanity check on what a vehicle might be.

**Goals:**
- Verify that a listing photo matches the advertised make and model
- Compare top predictions when the listing is vague or mislabeled
- Get results in seconds from a phone or laptop browser

**Pain points:**
- Stock photos and dealer watermarks can obscure the car
- Needs clear, readable output—not raw class names or probability decimals without labels
