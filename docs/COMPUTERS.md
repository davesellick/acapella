# Dave's computers

Every computer runs its own copy of Acapella, and since 02/10/2026 the Windows copies share
settings, dictionary, history and keys through sync. So a change made on one computer can
need something on the others: the same build (sync behaviour lives in each copy, and an older
build can undo a fix through what it pulls or pushes), a one-off repair to data a bug has
already damaged, or nothing at all. This file is where that gets remembered, because it lives
in the repo and reaches every computer with the code.

## The computers

| Computer | OS | App | Installed build | Updated |
|---|---|---|---|---|
| Sidgrove_9950x | Windows 11 | Windows app, signed in to sync | 0b8436f, put back from 7c30e09 by mistake (see below) | 04/11/2026 |
| Sidgrove_Razer | Windows 11 | Windows app, not signed in to sync (its previous build, 3e7d572, predated sync) | 822f093 | 25/10/2026 |
| Name not known yet: the other PC signed in to sync, seen pushing changes on 20/10/2026 | Windows | Windows app, signed in to sync | not known | not known |
| Mac | macOS 26 | Mac app, no sync yet | not known | not known |

Fill in a row the first time a computer is updated from this file; the name is what `hostname`
prints there.

## When Dave asks to update the app on a computer

1. **Find what it runs now.** On Windows the installed exe carries the commit it was built
   from, after the `+`:

   ```powershell
   (Get-Item "$env:LOCALAPPDATA\Programs\Acapella\Acapella.exe").VersionInfo.ProductVersion
   ```

   The Mac app does not stamp a commit yet, so go by the table.
2. **Do what is waiting for it.** Every entry below that names this computer gets done as
   part of the update, not after it.
3. **Install.** Windows: `windows\publish.ps1`, then `windows\install.ps1`, then read the
   version back as in step 1 and check it is the commit you meant. `install.ps1` only copies
   whatever is in that checkout's `windows\dist`, which git does not track, so on its own it
   can quietly put an old build back. It also force-stops the app, so a dictation in progress
   is lost: ask Dave first. Mac: `make install`.
4. **Update its row** in the table.
5. **Then think about the others.** Run `git log <build>..HEAD` from the oldest build in the
   table and look for anything that touches sync, settings, keys or a file format. For each
   computer still on an older build, add an entry below saying what it needs and why, and tell
   Dave in the reply which other computers now need updating. An update is not finished while
   the other computers go unmentioned.
6. **Commit this file** with the update. The other computers only see it once it is pushed,
   so ask Dave about pushing.

When a change is made rather than installed, the same rule applies: if it will need anything
on another computer, add the entry in the same commit as the change.

## Waiting on other computers

Remove an entry once every computer it names has had it.

- **Sidgrove_9950x was put back to 0b8436f on 04/11/2026.**
  Needed on: Sidgrove_9950x, a fresh publish and install from current main.
  Why: a Sidgrove Intelligence session ran `install.ps1` four times that day (09:31, 10:03,
  11:08 and 13:03) from the main checkout, whose `windows\dist` still held the build from
  12/10/2026, and reported the app as up to date. That took off 9ec772c, 27a1037, 405bbcf and
  the learner fixes a1e82d6 and e4d2e23. Hearing and clean-up code is the same in both builds.
- **9ec772c, sync keeps settings changed on the PC doing the pulling.**
  Needed on: every Windows computer signed in to sync. Sidgrove_9950x had it from 23/10/2026
  and lost it on 04/11/2026; still needed on the other PC.
  Why: the fix lives in the copy doing the pulling. A computer on an older build still lets a
  first sync after signing in overwrite settings chosen on it (how cloud hearing went off on
  Sidgrove_9950x on 19/10/2026), and it still logs nothing when a pull changes a setting.
  After installing: check that "Also hear me in the cloud" is set as Dave wants it there, and
  note that computer's name in the table; its log names other computers in lines that start
  `sync: settings from`.
- **601bb47, a rarely said fix waits for a second edit when Jev thinks it a change of mind.**
  Needed on: every Windows computer. Done on none yet; it sat on a local branch on
  Sidgrove_9950x from 23/10/2026 until it was merged on 03/11/2026, so no build before then
  has it.
  Why: the learner lives in each copy, so a computer on an older build still learns a hardly
  ever said fix after one edit whatever Jev made of it (how `not importantly` became
  `importantly not` on 23/10/2026). Nothing to repair; a rule already learnt that way can be
  removed in the Dictionary tab.
