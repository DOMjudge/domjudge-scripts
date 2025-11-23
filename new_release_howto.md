A new release can be created by one of the main DOMjudge developers.
The following steps should be taken (local directories refer to those
on the account `domjudge@vm-domjudge`):

 1. Test everything. (duh...)
 1. Commit the correct version number in the `ChangeLog` and `README` files.
 1. Discuss if the current second to last minor version will now be EOL.
 1. Update https://github.com/DOMjudge/domjudge/security/policy to support 2 minor versions, including     the one now being released.
 1. Change the constants `webapp/src/Controller/API/GeneralInfoController.php`
    to point to the correct CCS API version.
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
 1. Remove unsupported versions from the `versions.json` in the next step.
 1. If this is a new major or minor version, update the release documentation
    under `/srv/http/domjudge/docs/manual` by adding a new version to the
    file `versions.json` and updating the redirect destination in `index.html`
    and `team.html`. The documentation is regenerated once every hour.
 1. Add the new version to the dependabot configuration
    [here](https://github.com/DOMjudge/domjudge/blob/main/.github/dependabot.yml).
 1. Bump the Docker images by starting a new pipeline
    [here](https://gitlab.com/DOMjudge/domjudge-packaging/-/pipelines/new) and
    setting `DOMJUDGE_VERSION` to the version to release. Set `DOMJUDGE_LATEST`
    to true if this is the latest version or `false` if it is not. After clicking
    `Run pipeline`, make sure to click the *play* button next to `release-DOMjudge`
    to actually build and push the Docker images. You can view the progress by
    clicking on the job.
 1. Update https://gitlab.com/DOMjudge/domjudge-packaging/-/pipeline\_schedules to the latest version.
 1. Build Debian packages (or make someone do this).
 1. Put debian packages in `/srv/http/domjudge/debian/mini-dinstall/incoming`
    and run as domjudge@domjudge: `mini-dinstall -b`
 1. Send an email to `domjudge-announce@domjudge.org`, announcing the new version and state which versions are supported.
 1. Add the released branch to the dependabot.yml (https://github.com/DOMjudge/domjudge/blob/main/.github/dependabot.yml)
