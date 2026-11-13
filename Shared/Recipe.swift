import SwiftUI
import UIKit

struct Recipe {
    let name: LocalizedStringKey
    let metadata: [LocalizedStringKey]
    let image: String?
    let photo: Data?

    var picture: UIImage? {
        if let photo { return UIImage(data: photo) }
        return image.flatMap { UIImage(named: $0) }
    }
    let ingredients: [Ingredient]
    let steps: [CookingStep]

    struct Ingredient: Identifiable {
        let id: String
        let text: LocalizedStringKey
    }

    static let sample = Recipe(
        name: "recipe.soup.name",
        metadata: ["recipe.soup.category", "recipe.soup.time", "recipe.soup.servings"],
        image: "Soup",
        photo: nil,
        ingredients: [
            .init(id: "squash", text: "ingredient.squash"),
            .init(id: "onion", text: "ingredient.onion"),
            .init(id: "garlic", text: "ingredient.garlic"),
            .init(id: "oil", text: "ingredient.oil"),
            .init(id: "stock", text: "ingredient.stock"),
            .init(id: "cream", text: "ingredient.cream"),
            .init(id: "sage", text: "ingredient.sage"),
            .init(id: "seasoning", text: "ingredient.seasoning")
        ],
        steps: CookingStep.soup
    )
}

extension Recipe {
    init(saved: SavedRecipe) {
        name = LocalizedStringKey(saved.title)
        var details: [LocalizedStringKey] = []
        if let category = saved.category { details.append(LocalizedStringKey(category)) }
        if let minutes = saved.totalMinutes ?? saved.prepMinutes { details.append("\(minutes) min") }
        if let servings = saved.servings { details.append(LocalizedStringKey(servings)) }
        metadata = details
        image = nil
        photo = saved.photo
        ingredients = saved.ingredients.enumerated().map {
            Ingredient(id: String($0.offset), text: LocalizedStringKey($0.element))
        }
        steps = saved.steps
    }
}
