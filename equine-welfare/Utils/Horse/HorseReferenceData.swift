import Foundation

/// Canonical option lists for horse attributes. Kept out of the view layer so
/// they can be reused (validation, other screens) and edited without touching
/// UI code. The pickers still accept free-text "Other…" entries, so these are
/// suggestions, not a closed set.
enum HorseReferenceData {
    static let sexes: [String] = ["Mare", "Stallion", "Gelding"]

    static let breeds: [String] = [
        "Quarter Horse", "Appendix Quarter Horse", "Quarter Horse cross", "Standardbred",
        "Pony", "Halflinger", "Paint", "Appaloosa", "Miniature Horse", "Percheron",
        "Belgian", "Clydesdale", "Hannoverian", "Warmblood", "Warmblood cross",
        "Draft cross", "Arabian", "Arabian cross", "Thoroughbred", "Thoroughbred cross",
        "Saddlebred", "Morgan", "Cross", "Donkey", "Unknown",
    ]

    static let colors: [String] = [
        "Albino", "Appaloosa", "Apricot", "Bay", "Bay Dun", "Bay Overo", "Bay Roan",
        "Bay Tobiano", "Bay Tovero", "Bay w/Blanket", "Bay/White", "Black", "Black Bay",
        "Blackgrey", "Black Overo", "Black Roan", "Black Tobiano", "Black Tovero",
        "Black w/Blanket", "Black/White", "Blonde", "Blond/Sorrel", "Blue Roan",
        "Blue Roan Overo", "Blue Roan Tobiano", "Blue Roan w/Blanket", "Brown", "Brown Dun",
        "Brown/White", "Buckskin", "Buckskin/Grulla", "Buckskin Overo", "Buckskin Tobiano",
        "Buckskin w/Blanket", "Buckskin/White", "Caramel", "Champagne", "Chestnut",
        "Chestnut Overo", "Chestnut Roan", "Chestnut Tobiano", "Chestnut w/Blanket",
        "Chestnut/White", "Chocolate", "Chocolate/Palomino", "Chocolate/White", "Cream",
        "Cremella", "Cremello", "Dapple", "Dapple Gray", "Dark Bay", "Dark Bay Blue Roan",
        "Dark Bay/Brown", "Dark Bay/White", "Dark Brown", "Dark Dun", "Double Dapple", "Dun",
        "Dunalino", "Dun Overo", "Dun Tobiano", "Dun w/Blanket", "Dun/White",
        "Flea Bitten Grey", "Gray", "Gray w/Blanket", "Gray/White", "Grey", "Grey Dapple",
        "Grey Dun", "Grey/White", "Grulla", "Grulla/White", "Grullo", "Grullo Champagne",
        "Grullo Overo", "Grullo/White", "Leopard", "Lineback Dun", "Liver", "Liver Chestnut",
        "Liver Chestnut w/Blanket", "Overo", "Paint", "Palomino", "Palomino Overo",
        "Palomino/Tobiano", "Palomino w/Blanket", "Palomino/White", "Perlino", "Piebald",
        "Pinto", "Raicano", "Red Chocolate", "Red Dun", "Red Dun w/Blanket", "Red Roan",
        "Red Roan Overo", "Red Roan Tobiano", "Red Roan w/Blanket", "Red Snowflake", "Roan",
        "Roan Bay", "Roan Buckskin", "Roan Chestnut", "Roan Strawberry", "Roan/White",
        "Sable", "Seal Bay", "Seal Brown", "Silver", "Silver Dapple", "Silver Dapple Pinto",
        "Sorrel", "Sorrel Overo", "Sorrel Tobiano", "Sorrel/Tovero", "Sorrel w/Blanket",
        "Sorrel/White", "Strawberry Roan", "Tobiano", "Tri", "White",
    ]
}
