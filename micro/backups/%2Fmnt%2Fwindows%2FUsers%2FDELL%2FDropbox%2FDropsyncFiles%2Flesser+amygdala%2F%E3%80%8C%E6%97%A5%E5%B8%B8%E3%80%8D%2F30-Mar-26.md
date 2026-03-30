#include <iostream>
#include <string>
using namespace std;

class Event {
private:
    int participantID;
    string participantName;

    static int totalParticipants;

public:
    // Set participant details
    void setParticipant(int id, string name) {
        participantID = id;
        participantName = name;
        totalParticipants++;
    }

    // Get ID
    int getParticipantID() {
        return participantID;
    }

    // Display participant
    void display() {
        cout << "Participant ID: " << participantID
             << ", Name: " << participantName;
    }

    // Static function
    static int getTotalParticipants() {
        return totalParticipants;
    }
};

// Initialize static variable
int Event::totalParticipants = 0;

int main() {
    int n;
    cin >> n;

    Event participants[25];  // max size

    for (int i = 0; i < n; i++) {
        int id;
        string name;

        cin >> id;
        cin.ignore();               // clear newline
        getline(cin, name);         // full name input

        participants[i].setParticipant(id, name);
    }

    int searchID;
    cin >> searchID;

    bool found = false;

    for (int i = 0; i < n; i++) {
        if (participants[i].getParticipantID() == searchID) {
            cout << "Participant found: ";
            participants[i].display();
            cout << endl;
            found = true;
            break;
        }
    }

    if (!found) {
        cout << "Participant with ID " << searchID << " not found." << endl;
    }

    return 0;
}











































#include<iostream>
then stdlib
using namespace std;

class Matrix{
		public:
		Matrix(int n){
			int arr[n][n];
					}
		
};

#include <iostream>
using namespace std;

class Matrix {
    int n;
    int** mat;

public:
    // Constructor
    Matrix(int n) {
        this->n = n;
        mat = new int*[n];
        for (int i = 0; i < n; i++)
            mat[i] = new int[n];
    }

    // Read matrix
    void readMatrix() {
        for (int i = 0; i < n; i++)
            for (int j = 0; j < n; j++)
                cin >> mat[i][j];
    }

    // Display matrix
    void displayMatrix() {
        cout << "Matrix:\n";
        for (int i = 0; i < n; i++) {
            for (int j = 0; j < n; j++)
                cout << mat[i][j] << " ";
            cout << endl;
        }
    }

    // Helper to compute determinant of submatrix
    int determinantOfSubMatrix(int** subMatrix, int subSize) {
        if (subSize == 1)
            return subMatrix[0][0];

        if (subSize == 2)
            return subMatrix[0][0] * subMatrix[1][1] -
                   subMatrix[0][1] * subMatrix[1][0];

        int det = 0;

        for (int col = 0; col < subSize; col++) {
            // Allocate submatrix
            int** temp = new int*[subSize - 1];
            for (int i = 0; i < subSize - 1; i++)
                temp[i] = new int[subSize - 1];

            // Fill submatrix (skip row 0 and current column)
            for (int i = 1; i < subSize; i++) {
                int subCol = 0;
                for (int j = 0; j < subSize; j++) {
                    if (j == col) continue;
                    temp[i - 1][subCol++] = subMatrix[i][j];
                }
            }

            // Cofactor expansion
            int sign = (col % 2 == 0) ? 1 : -1;
            det += sign * subMatrix[0][col] *
                   determinantOfSubMatrix(temp, subSize - 1);

            // Free memory
            for (int i = 0; i < subSize - 1; i++)
                delete[] temp[i];
            delete[] temp;
        }

        return det;
    }

    // Determinant function
    int determinant() {
        return determinantOfSubMatrix(mat, n);
    }

    // Destructor
    ~Matrix() {
        for (int i = 0; i < n; i++)
            delete[] mat[i];
        delete[] mat;
    }
};

int main() {
    int n;
    cin >> n;

    Matrix m(n);
    m.readMatrix();
    m.displayMatrix();

    cout << "Determinant: " << m.determinant() << endl;

    return 0;
}
