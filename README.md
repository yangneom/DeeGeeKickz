# Flutter-Thesis
elow

# Making a new branch for each module
# Switch me to the dev branch
git checkout dev
# Create a new branch called feature/inventory and switch to it immediately
git checkout -b feature/
# The -b means "create new branch". Without -b it just switches to an existing branch. With -b it creates AND switches in one command.
git branch feature/inventory   ← create it
git checkout feature/inventory ← switch to it
# Upload this new branch to GitHub so it exists online too
git push -u origin feature/inventory


# 1. Before coding - check your status
git status

# 2. After coding - save your work
git add .
git commit -m "describe what you did"
git push