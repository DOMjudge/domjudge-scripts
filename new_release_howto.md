A new release can be created by one of the main DOMjudge developers.
The following steps should be taken (local directories refer to those
on the account `domjudge@vm-domjudge`):

 1. Test everything. (duh...)
 1. Commit the correct version number in the `ChangeLog` and `README` files.
 1. `export TAG=x.y.z`
 1. Create a release version `$TAG` in Git with `$TAG` the version number
    x.y.z:
    ```sh
        git tag -s -m "Tag release version $TAG." $TAG
    ```
    See `git tag --help` for more details on how to tag with(out) a
    GPG signature.
 1. Don't forget to push everything to the central Git repository
    (especially the release tags, since these are not pushed by default),
    e.g. with
        `git push origin ${TAG%.?} refs/tags/$TAG`
 1. If releasing from the main branch, create a new version branch:
    ```{sh}
    git checkout -b x.y
    git push --set-upstream origin x.y
    git checkout main
    ```
 1. Update files above to `{version+1}DEV` and commit.
 1. On the server the tarball will be built, signed and published.
 1. Update the DOMjudge homepage: commit changes in the `domjudge-scripts`
    repository under `website/` and run `make install` as domjudge@domjudge
 1. If this is a new major or minor version, update the release documentation
    under `/srv/http/domjudge/docs/manual` by adding a new version to the
    file `versions.json` and updating the redirect destination in `index.html`.
    The documentation is regenerated once every hour.
 1. Bump the docker containers and build Debian packages (or make someone
    do this).
 1. Put debian packages in `/srv/http/domjudge/debian/mini-dinstall/incoming`
    and run as domjudge@domjudge: `mini-dinstall -b`
 1. Send an email to `domjudge-announce@domjudge.org`.
