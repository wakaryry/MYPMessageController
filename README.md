# MYPMessageController

[![CI Status](https://img.shields.io/travis/wakaryry/MYPMessageController.svg?style=flat)](https://travis-ci.org/wakaryry/MYPMessageController)
[![Version](https://img.shields.io/cocoapods/v/MYPMessageController.svg?style=flat)](https://cocoapods.org/pods/MYPMessageController)
[![License](https://img.shields.io/cocoapods/l/MYPMessageController.svg?style=flat)](https://cocoapods.org/pods/MYPMessageController)
[![Platform](https://img.shields.io/cocoapods/p/MYPMessageController.svg?style=flat)](https://cocoapods.org/pods/MYPMessageController)

MYPMessageController is a message style controller with a growable textview input.

It could be used in many cases, especailly in conversation style or comment style or discussion style.

![message style controller with growable input view](https://github.com/wakaryry/MYPMessageController/blob/master/controller.jpg)

![table view and cell inverted supported](https://github.com/wakaryry/MYPMessageController/blob/master/inverted.jpg)

## Features
- configurable action and surfaces: 
    - 4 default buttons within text inputbar suitable for almost every cases.
    - You can change or configure all the buttons look and action, of cource including removing from the visible view.
    - APIs are ready. You just need to override or implement in your subclass.
    - all the other surfaces are configurable, such as background color, divider line, font, contentSize, margin, ...
- growable taxt view input:
    - initial 1 line height and then could grow depend on text inputed.
    - max number of lines visible limited. It has a max height. Scrollable to see other text.
- Undo/Redo supported:
    - 10 undo/redo levels.
- text caches supported:
    - cache input text supported.
    - open API to configure cache enviroment.
- oritation/rotation supported:
    - with all direction or rotation supported.
- ipad compatible.
- table view, collection view, scroll view supported.
- inverted arrange supported.
- autoCompletion supported.
- external keyboard supported.
- storyboad and programming supported.

## To do
- more convenient for markdown input.
- markdown input supported.
- markdown cell.
- default emotion keyboard.
- more cell style and surfaces.
- more examples or use cases.
- documentation.

## Design structure
Coming soon

## How to use
Coming soon

## Connect
Wechat: pptpdf

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

MYPMessageController is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'MYPMessageController'
```

## Author

mayuping321@163.com, redoume@163.com

## License

MYPMessageController is available under the MIT license. See the LICENSE file for more info.
