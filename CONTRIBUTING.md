# Contributing to Secretive

Thanks for your interest in contributing to Secretive! Before you contribute, there are a few things I'd like to lay out.

## Security

Security is obviously paramount for a project like Secretive. As such, any contributions that compromise the security or auditabilty of the project will be rejected.

### Dependencies

Secretive is designed to be easily auditable by people who are considering using it. In keeping with this, Secretive has no third party dependencies, and any contributions which bring in new dependencies will be rejected.

## Code of Conduct

All contributors must abide by the [Code of Conduct](CODE_OF_CONDUCT.md)

## Localization

If you'd like to contribute a translation, please see [Localizing](LOCALIZING.md) to get started.

## Credits

If you make a material contribution to the app, please add yourself to the end of the [credits](https://github.com/maxgoedjen/secretive/blob/main/Sources/Secretive/Credits.rtf).

## Collaborator Status

I will not grant collaborator access to any contributors for this repository. This is basically just because collaborators [can accesss the secrets Secretive uses for the signing credentials stored in the repository](https://docs.github.com/en/actions/reference/encrypted-secrets#accessing-your-secrets).

## Secretive is Opinionated

I'm releasing Secretive as open source so that other people can use it and audit it, feeling comfortable in knowing that the source is available so they can see what it's doing. I have a pretty strong idea of what I'd like this project to look like, and I may respectfully decline contributions that don't line up with that vision. If you'd like to propose a change before implementing, please feel free to [Open an Issue with the proposed tag](https://github.com/maxgoedjen/secretive/issues/new?labels=proposed).
