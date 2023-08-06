# VIPER+ Architecture for Swift
📱📱📱 The best architecture for an iOS app


VIPER+ is an advanced variant of the VIPER architecture, specifically designed for Swift projects, leveraging the language's features such as protocol extensions, protocol composition, type safety, and more. It provides a robust, scalable, and maintainable architecture to build iOS applications with a clear separation of concerns.

## Overview

VIPER+ promotes the principle of "separation of concerns" by dividing the application into distinct layers:

- **View**: Responsible for UI rendering and user interactions.
- **Interactor**: Contains business logic and communicates with the Data Layer.
- **Presenter**: Acts as a mediator between the View and the Interactor.
- **Entity**: Represents application data and business objects.
- **Router**: Handles navigation and routing.

## Features

1. **Type Safety**: VIPER+ takes full advantage of Swift's type safety, making your codebase less error-prone and more reliable.

2. **Protocol Extensions**: Protocol extensions are used to provide default implementations, reducing boilerplate code while still maintaining adherence to the VIPER architecture.

3. **EndpointProvider**: The `EndpointProvider` class provides a big picture of network operations, allowing for a separate and loosely coupled network layer. It simplifies API calls and data handling.

4. **Mock Data Support**: VIPER+ offers the ability to fetch mock data from local JSON files or create custom mock implementations. This is especially useful for testing and development purposes.

5. **Scalable and Maintainable**: The architecture's modular nature and clear separation of concerns make it easy to scale and maintain your application as it grows in complexity.

## Architecture Diagram

![This is architecture.](https://github.com/burhanaras/VIPER-Plus/blob/main/VIPER-Plus.png?raw=true "This is architecture diagram for Recipes App.")

VIPER+ follows a strict separation of concerns, dividing the application into three distinct layers:

### Presentation Layer

The Presentation Layer contains all UI-related classes, such as ViewControllers and Views. Each View has a corresponding Presenter class that handles UI logic, such as updating the view and handling user interactions. This layer is strictly responsible for the UI and does not contain any business logic.

### Domain Layer

The Domain Layer houses Interactors, which are responsible for handling the business logic of the application. Each Interactor has a single responsibility, making it easy to manage and understand. Additionally, Model classes reside in this layer, representing the application data and business objects.

### Network Layer

The Network Layer handles all network-related operations, including data fetching from external data sources. Service classes connect to the data source and fetch the required data. Each Service class has a single responsibility, making the network layer modular and maintainable.

A key feature of the Network Layer is the ability to dynamically switch endpoints. This flexibility allows for easy switching between different API endpoints during development, testing, and production. The EndPointProvider protocol contains a full list of network operations, enabling Interactors to extend as many service classes as needed. This feature harnesses the power of Swift's protocol extensions and protocol composition, providing Interactors with additional capabilities in a clean and modular way.


## Sample Usage

```swift
let baseAPIURL = URL(string: "https://api.coingecko.com/api/v3/")!
let networkLayer = URLSessionNetworkLayer(logger: nil, baseAPIURL: baseAPIURL)
let endpointProvider = ExampleEndpointProvider(baseAPIURL: baseAPIURL)

let presenter = CoinsPresenter(interactor: CoinsInteractorImpl(networkLayer: networkLayer, endpointProvider: endpointProvider))
let coinsListView = CoinsListView(presenter: presenter)


```

## Getting Started

To use VIPER+ in your project, follow these steps:

1. Clone the repository to your local machine.

2. Integrate the VIPER+ architecture into your Xcode project.

3. Implement your View, Interactor, Presenter, Entity, and Router classes following the VIPER+ guidelines.

4. Use the `EndpointProvider` class to handle network operations with ease.

5. Leverage the mock data support for testing and development purposes.

## Contribution

We welcome contributions to enhance VIPER+ and make it even better. If you find any issues or have suggestions for improvements, please feel free to open an issue or create a pull request.

## License

VIPER+ is open-source and available under the [MIT License](LICENSE).

---

With VIPER+, building Swift-based iOS applications becomes more organized, modular, and efficient. It allows you to focus on the core functionality of your app while keeping a clear separation between different components. Enjoy the benefits of Swift's language features combined with the flexibility of the VIPER architecture!

Happy coding! 🚀

📱📱📱Developed by [Burhan ARAS](http://www.burhanaras.net) with all the love on planet.
