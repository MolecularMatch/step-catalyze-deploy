# Catalyze deployment step

[![wercker status](https://app.wercker.com/status/01748d9be54fc2fb46fc8c7d90cff1b9/m "wercker status")](https://app.wercker.com/project/bykey/01748d9be54fc2fb46fc8c7d90cff1b9)

Deploy your code to Catalyze. This step requires that you deploy to a Custom deploy target.


# Using wercker SSH key pair

To push to Catalyze we need to have an ssh key that is registered with their application.

To do this you must generate a private/public key pair on wercker and manually add the public key to Catalyze.

- Generate a new key in wercker in the `Key management` section (`application` - `settings`).
- Copy the public key and add it to Catalyze
- In wercker edit the Custom (Catalyze) deploy target to which you would like to deploy, and add an environment variable:
    - Give the environment variable a name (remember this name, you will need it in the last step).
    - Select `SSH Key pair` as the type and select the key pair which you created earlier.
- In the `catalyze-deploy-step` step in your `wercker.yml` add the `key-name` property with the value you used earlier:

``` yaml
deploy:
    steps:
        - MolecularMatch/catalyze-deploy-step:
            key-name: MY_DEPLOY_KEY
```

In the above example the `MY_DEPLOY_KEY` should match the environment variable name you used in wercker. Note: you should not prefix it with a dollar sign or post fix it with `_PRIVATE` or `_PUBLIC`.

# What's new


# Options

* `key-name` (required) Specify the name of the key that should be used for this deployment.
* `CATALYZE_APP_NAME` (required) Specify the name of the application that should be used for this deployment.
* `CATALYZE_USER` (optional) Specify the name of the user that will be performing deployments (default: catalyze-deploy@wercker.com)

# Example

``` yaml
deploy:
    steps:
        - MolecularMatch/catalyze-deploy-step:
            key-name: MY_DEPLOY_KEY
```

# Special thanks

# License

The MIT License (MIT)

# Changelog

## 0.0.2
* Corrected environment variable to handle what wercker actually provides

## 0.0.1

* Initial release.