# Generating logos from a Contest Package

```bash
for team in $(cat ~/wf2021/contests/finals/teams.json | jq -r '.[].id'); do
    echo $team
    ORG_ID=$(cat ~/wf2021/contests/finals/teams.json | jq -r ".[] | select(.id == \"$team\") | .organization_id")
    convert ~/wf2021/contests/finals/organizations/$ORG_ID/logo.png -resize 64x64 -background none -gravity center -extent 64x64 $team.png
done
```

# Generating photos from a Contest package

```bash
for team in $(cat ~/wf2021/contests/finals/teams.json | jq -r '.[].id'); do
    echo $team
    ORG_ID=$(cat ~/wf2021/contests/finals/teams.json | jq -r ".[] | select(.id == \"$team\") | .organization_id")
    TEAM_NAME=$(cat ~/wf2021/contests/finals/teams.json | jq -r ".[] | select(.id == \"$team\") | .display_name")
    convert ~/wf2021/contests/finals/teams/$team/photo.jpg -fill white -undercolor '#00000080' -gravity south -font 'Ubuntu' -pointsize 30 -annotate +5+5 " $TEAM_NAME " ~/wf2021/contests/finals/organizations/$ORG_ID/logo.160x160.png -gravity northeast -composite -resize 1024x1024 $team.png
done
```