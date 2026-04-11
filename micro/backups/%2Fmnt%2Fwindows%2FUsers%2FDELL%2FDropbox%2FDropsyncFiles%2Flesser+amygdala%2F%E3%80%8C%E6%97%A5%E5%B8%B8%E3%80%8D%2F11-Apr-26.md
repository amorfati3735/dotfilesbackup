quick
#include <stdio.h>

// partition function
int partition(int a[], int low, int high) {
    int pivot = a[high];     // choose last element as pivot
    int i = low - 1;         // smaller element index

    for (int j = low; j < high; j++) {
        if (a[j] < pivot) {
            i++;
           swap ai and aj        }
    }

    // place pivot in correct position
    int temp = a[i + 1];
    a[i + 1] = a[high];
    a[high] = temp;

    return i + 1;   // pivot index
}

// recursive quicksort
void quickSort(int a[], int low, int high) {
    if (low < high) {
        int pi = partition(a, low, high);  // pivot index

        quickSort(a, low, pi - 1);   // left side
        quickSort(a, pi + 1, high);  // right side
    }
}






merge


---
insertion
for(i=1 to n)
int key=ar[i];
int j=i-1;
while(j>=0 && ar[j]>key){
	ar[j+1]=ar[j];
	j--;
}
ar[j+1]=key;

bubble
for(int i=0 to n-1)
for(int j=0 to n-1-i)
if arr[j]>arr[j+1]
swap
---
selection
for(int i=0 to n-1)
min=ar[i]
for(int j=i+1 to n)
if arr[j]<arr[min]
min=j
}
swap ar[i] and ar[min] inside outer for
---

//stack implementation
int s[n];
top=-1
void push(int x){
	if top==n-1 overflow
	else s[++top]=x;
}
void pop(){
	if top==-1 underflow
	else top--;
}
void disp(){
	loop 0 to top and print
}

//queue implementation

int q[n];
int front=rear=-1;

void insert(int x){
if(rear==n-1) overflow

	if(front==-1) front=0;
		
	q[++rear]=x;
	return;
}
void remove(){
	if(front==rear=-1) underflow
	else front++;
	//when empty reset queue
	if(front>rear) front=rear=-1;
	 
}

queue done
