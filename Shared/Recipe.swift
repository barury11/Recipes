import SwiftUI

struct Recipe {
    let name: LocalizedStringKey
    let category: LocalizedStringKey
    let time: LocalizedStringKey
    let servings: LocalizedStringKey
    let image: String
    let ingredients: [Ingredient]
    let steps: [CookingStep]

    struct Ingredient: Identifiable {
        let id: String
        let text: LocalizedStringKey
    }

    static let sample = Recipe(
        name: "recipe.soup.name",
        category: "recipe.soup.category",
        time: "recipe.soup.time",
        servings: "recipe.soup.servings",
        image: "Soup",
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
