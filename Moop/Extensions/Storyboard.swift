//
//  Storyboard.swift
//  Moop
//
//  Created by kor45cw on 31/07/2019.
//  Copyright © 2019 kor45cw. All rights reserved.
//

import kor45cw_Extension

enum Storyboard: StoryboardName {
    case main
    case movie
    case detail
    case setting
    case alarm
    case filter
    
    var name: String {
        switch self {
        case .main: return "Main"
        case .movie: return "Movie"
        case .detail: return "Detail"
        case .setting: return "Setting"
        case .alarm: return "Alarm"
        case .filter: return "Filter"
        }
    }
}
