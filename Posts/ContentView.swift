import SwiftUI

struct ContentView: View {
    @StateObject var postManager = PostManager()
    @State var showModal = false
    
    
    var body: some View {
        NavigationView {
            List {
                ForEach(postManager.posts) { post in
                    NavigationLink(destination: PostDetailView(post: post)) {
                        VStack(alignment: .leading) {
                            Text(post.title)
                                .font(.headline)
                            Text(post.body)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Posts")
            .onAppear {
                postManager.fetchPosts()
            }
            .navigationBarItems(trailing: Button(action: {
                showModal = true
            }, label: {
                Image(systemName: "plus")
            }))
            .sheet(isPresented: $showModal, content: {
                AddPostView()
                    .environmentObject(postManager)
            })
            .refreshable {
                postManager.fetchPosts()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct Posts: Codable {
    var results: [Post]
}

struct Post: Codable, Identifiable {
    var id: String?
    var userId: Int?
    var title: String
    var body: String
    var createdAt: String?
}

class PostManager: ObservableObject {
    @Published var posts = [Post]()
    var selectedPost: Post?
    
    func fetchPosts() {
        URLSession.shared.dataTask(with: URL(string: "https://jvrvrzemc6.execute-api.us-west-2.amazonaws.com/dev/posts")!) { data, response, error in
            guard let data = data else {
                print("Error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            do {
                let decodedData = try JSONDecoder().decode([Post].self, from: data)
                DispatchQueue.main.async {
                    self.posts = decodedData
                }
            } catch let error {
                print("Error: \(error.localizedDescription)")
            }
        }
        .resume()
    }
    
    func addPost(post: Post, completion: @escaping (Result<Post, Error>) -> Void) {
        guard let url = URL(string: "https://jvrvrzemc6.execute-api.us-west-2.amazonaws.com/dev/post") else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        guard let jsonData = try? JSONEncoder().encode(post) else {
                    print("Error: Trying to convert model to JSON data")
                    return
                }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data else {
                completion(.failure(error ?? NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])))
                return
            }
            
            do {
                let post = try JSONDecoder().decode(Post.self, from: data)
                completion(.success(post))
            } catch let error {
                completion(.failure(error))
            }
        }
        .resume() // Start the data task
    }
    
    func deletePost(id: String) {
            guard let url = URL(string: "https://jvrvrzemc6.execute-api.us-west-2.amazonaws.com/dev/post/\(id)") else {
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print(error)
                    return
                }
                
                guard let data = data else {
                    return
                }
                
                do {
                    let result = try JSONDecoder().decode(DeleteResponse.self, from: data)
                    if result.success {
                        DispatchQueue.main.async {
                            if let index = self.posts.firstIndex(where: { $0.id == id }) {
                                self.posts.remove(at: index)
                            }
                        }
                    }
                } catch let error {
                    print(error)
                }
            }.resume()
        }
    
    func updatePost(id: String, title: String, body: String) {
            guard let url = URL(string: "https://jvrvrzemc6.execute-api.us-west-2.amazonaws.com/dev/post/\(id)") else {
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            
            let params: [String: Any] = [
                "title": title,
                "body": body
            ]
            
            request.httpBody = try? JSONSerialization.data(withJSONObject: params, options: [])
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print(error)
                    return
                }
                
                guard let data = data else {
                    return
                }
                
                do {
                    let post = try JSONDecoder().decode(Post.self, from: data)
                    DispatchQueue.main.async {
                        if let index = self.posts.firstIndex(where: { $0.id == post.id }) {
                            self.posts[index] = post
                        }
                    }
                } catch let error {
                    print(error)
                }
            }.resume()
        }
    
    struct DeleteResponse: Decodable {
        let success: Bool
    }

}

struct PostDetailView: View {
    @StateObject var postManager = PostManager()
    @Environment(\.presentationMode) var presentationMode
    @State var editMode = false
    @State var post: Post
    
    var body: some View {
        VStack(alignment: .leading) {
            if editMode {
                TextField("Title", text: $post.title)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Body", text: $post.body)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            } else {
                Text("Created at: \(post.createdAt!)")
                    .foregroundColor(.secondary)
                    .padding()
                Text("Title: \(post.title)")
                    .font(.headline)
                Text("Body: \(post.body)")
                    .foregroundColor(.secondary)
                
            }
            Spacer()
            HStack {
                if editMode {
                    Button("Save") {
                        postManager.updatePost(id: post.id!, title: post.title, body: post.body)
                        editMode.toggle()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                } else {
                    Button("Edit") {
                        editMode.toggle()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.yellow)
                }
                Button("Delete Post") {
                    postManager.deletePost(id: post.id!)
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding()
        .navigationBarTitle(Text(post.title), displayMode: .inline)
    }
}

struct AddPostView: View {
    @EnvironmentObject var postManager: PostManager
    @State private var title = ""
    @State private var postBody = ""
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Title")) {
                    TextField("Title", text: $title)
                }
                Section(header: Text("Body")) {
                    TextEditor(text: $postBody)
                }
            }
            .navigationBarTitle("New Post", displayMode: .inline)
            .navigationBarItems(trailing:
                Button(action: {
                    let post = Post(title: title, body: postBody)
                postManager.addPost(post: post) {_ in}
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Add")
                }
                .disabled(title.isEmpty || postBody.isEmpty)
            )
        }
    }
}
