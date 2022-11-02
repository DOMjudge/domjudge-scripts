## DOMjudge EOC ansible helper
This ansible playbook should automate must of the tasks DOMjudge needs to perform for the End Of Contest procedures during the ICPC WF's. It was created for the WF 2021 in Dhaka, which took place in 2022.

Two types of authentication are used and supported. Session based auth and basic auth.
 - Session based auth retrieves a CSRF token and fakes a login action.
 - Basic auth headers are constructed and used. This is to fully mitigate [annoying basic-auth issues](https://askubuntu.com/questions/1070838/why-wget-does-not-use-username-and-password-in-url-first-time/1070847#1070847), even though the `force_basic_auth` option should already prevent these issues from arising.

The full playbook can be run using the following command. See the setup section to see what the contents of facts.yml are supposed to be.

```ansible-playbook main.yml --extra-vars "@facts.yml" --tags all```

### Steps automated.
The following steps from the EOC 2022-Oct document have been automated:

29. `Primary pushes results.tsv into git repo`. Tag for just this action: `results.tsv`. Note, a manual commit is still needed!
32. `Compare scoreboard.json between primary and shadow`. Tag for just this action: `scoreboard`. Note, only if other (shadow or primary) credentials are provided.
33. `Compare awards.json between primary and CDS`. Tag for just this action: `awards`. Note, only if CDS credentials are provided.
36. `Verify that Primary and ... System Test`. Tag for just this action: `fetch`. Note, a manual commit is still needed and the `final_standings.html` is actually the static-scoreboard zip.


## Setup
To run this playbook a facts-file is required. An example of which can be seen below. Facts prefixed with:
 - `dj_` are for interaction with a DOMjudge instance.
 - `other_` are for interaction with another CLICS spec compliant CCS (commonly shadow if DOMjudge is primary, or vica versa)
 - `cds_` are for interaction with the CDS (also CLICS compliant).

Only the `repo`, `contest`, `contest_id`, and `dj_*` variables are required. When the `other_` or `cds_` facts are missing, steps which would interact with these systems are skipped.

- `repo` must point to where all retrieved files should be stored, not simply the repo root!
- `contest` must be the externalID.
- `contest_id` must be the internalID. (cID)
- `jd_loc` must point to the location of a [`jd` binary](https://github.com/josephburnett/jd/releases/tag/v1.6.1). Used for comparing diffs.

```yaml
repo: /home/mart/icpc/wf_repo
contest: bapc2022
contest_id: 2
jd_loc: /home/mart/icpc/EOC/jd

dj_url: https://judge.gehack.nl
dj_url_api_suffix: api/v4
dj_username: mart
dj_password: REDACTED

other_url: https://judge.gehack.nl
other_url_api_suffix: api/v4
other_username: mart
other_password: REDACTED

cds_url: https://cds.gehack.nl
cds_url_api_suffix: api
cds_username: admin
cds_password: REDACTED
```

## Selectively running the playbook
The playbook has multiple tags:
 - `all`: runs all tasks
 - `check`: Checks the consistency of both scoreboard.json and awards.json against the CDS and other CCS when configured.
 - `scoreboard`: Verifies scoreboard.json against the CDS and other CCS when configured.
 - `awards`: Verifies awards.json against the CDS and other CCS when configured.
 - `results.tsv`: Downloads results.tsv from DOMjudge and stores it in the repo.
 - `fetch`: Retrieves all files required by the EOC including results.tsv


### Known limitations
 - The checks that verify whether the jsons are the same are *very* simple and I (Mart) have not yet found a reasonable way of actually checking them in a nice manner from ansible. Them matching would be a bigger red-flag than them having a difference. Still, the playbook fails when a difference is detected! To aid with (manual) verification the results of fetching the jsons is stored in `/tmp/[obj].[sys].json` with `[object]` either "awards" or "scoreboard" and `[sys]` either "dj", "cds", or "other".
