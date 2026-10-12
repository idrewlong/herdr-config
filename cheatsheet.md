# herdr cheat sheet          (q to close · prefix = ctrl+space)

## Start on another repo
- prefix shift+c        new workspace, then `cd ~/code/<repo>` (it names itself after the repo)
- or from any shell:    herdr workspace create --cwd ~/code/<repo> --label <repo>

## Move around
- alt+up / alt+down     previous / next workspace        (N) in the sidebar = its order
- alt+1..9              jump to tab N                    [N] before a tab name = its key
- alt+left / alt+right  previous / next tab
- ctrl+alt+arrows       move between panes
- prefix z              zoom the current pane
- prefix b              hide / show the sidebar

## Make things
- prefix c              new tab              prefix r          rename tab
- alt+enter / prefix h  split side by side   alt+shift+enter   split top / bottom
- prefix shift+r        rename workspace     prefix shift+o    rename pane

## Popups
- prefix i              this cheat sheet
- prefix alt+g          lazygit
- prefix u              Claude usage dock (5h / weekly)
- prefix ?              herdr's own key list

## Finish with a project
- pause:   just switch away; agents keep running, a sound + popup tells you when one needs you
- done:    prefix shift+k closes the workspace
- leave:   prefix d detaches; run `herdr` to get everything back

## What the bars mean
- sidebar agent:  ▰▰▰▱ 3/8 todos · current step · latest action ($ cmd ✎ edit ↯ agent ⌕ search)
                  ctx / 5h / wk usage bars (green → orange → yellow → red)
- sidebar space:  ●working ▲blocked ✓done · branch · summed todo bar
- tab bar:        all agents' states · all todos · Claude 5h / weekly usage · host · time
- sounds:         soft chime = done   ·   double ping = needs you
