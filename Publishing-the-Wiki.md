# Publishing the Wiki

GitHub Wikis are a **separate Git repository** from the main project. This folder (`wiki/` in the clone) holds Markdown you can copy there and push.

## 1. Enable the wiki on GitHub

On GitHub: repository **Settings** → **Features** → enable **Wikis** (if disabled).

## 2. Customize links

Search and replace in all `wiki/*.md` files:

- `YOUR_ORG` → your GitHub username or organization name.

Alternatively use your repo’s full URL everywhere you prefer explicit links.

## 3. Clone the wiki repo

```bash
# Replace YOUR_ORG and REPO (e.g. Visual_Data_Transfer)
git clone https://github.com/YOUR_ORG/REPO.wiki.git vdt-wiki
cd vdt-wiki
```

If the wiki is empty, GitHub may create it on first push.

## 4. Copy wiki pages from this project

From your **main** repository checkout (adjust paths):

```bash
cp /path/to/Visual_Data_Transfer/wiki/*.md .
```

Ensure at least:

- `Home.md` — landing page  
- `_Sidebar.md` — navigation (GitHub renders this in the wiki UI)

## 5. Commit and push

```bash
git add -A
git status
git commit -m "docs(wiki): initial Visual Data Transfer wiki"
git push origin master
```

If the default branch is `main`:

```bash
git push -u origin main
```

(Use the branch GitHub shows for the wiki repo — often `master`.)

## 6. Verify on GitHub

Open **Wiki** tab on the repository; confirm **Home** and sidebar links resolve.

## Keeping the wiki in sync

Options:

1. **Manual** — repeat copy + push when onboarding docs change.  
2. **Script** — rsync/cp from `wiki/` into a clone of `REPO.wiki.git` and commit.  
3. **Single source** — treat `docs/` as canonical; keep wiki pages short with links into `main` (as here).

---

**Tip:** Wiki Markdown supports `[Page-Name](Page-Name)` links between pages; filenames like `Getting-Started.md` map to the **Getting-Started** page in the sidebar and URLs.
